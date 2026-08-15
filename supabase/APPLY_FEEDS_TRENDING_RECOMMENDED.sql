-- Paste this ENTIRE file into Supabase SQL Editor and click Run.
-- Dashboard: https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new
-- Safe to re-run. Adds New/Trending/Recommended feed RPCs + interaction tracking.
-- Source: migrations/20260906_feeds_trending_recommended_interactions.sql

-- =============================================================================
-- FirstVue — Feeds: New / Trending / Recommended RPCs, interaction tracking,
-- expanded impression sources, and affiliation query fixes.
-- Non-destructive; preserves existing data and RLS posture.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Expand post_impressions.feed_source for Feeds tabs
-- ---------------------------------------------------------------------------
alter table public.post_impressions
  drop constraint if exists post_impressions_feed_source_check;

alter table public.post_impressions
  add constraint post_impressions_feed_source_check
  check (feed_source in (
    'main', 'group', 'community', 'profile', 'vue', 'other',
    'trending', 'new', 'recommended'
  ));

-- ---------------------------------------------------------------------------
-- 2) Lightweight feed interaction events (source-aware)
-- ---------------------------------------------------------------------------
create table if not exists public.feed_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  interaction_type text not null
    check (interaction_type in (
      'impression', 'view', 'spark', 'unspark', 'comment', 'save', 'unsave',
      'share', 'repost', 'skip', 'hide', 'not_interested', 'report',
      'watch', 'profile_visit', 'follow_from_feed'
    )),
  watch_time_ms integer not null default 0,
  completion_percent numeric(5,2),
  source_tab text not null default 'main'
    check (source_tab in (
      'main', 'community', 'group', 'trending', 'new', 'recommended',
      'profile', 'vue', 'other'
    )),
  session_id text,
  created_at timestamptz not null default now()
);

create index if not exists feed_interactions_user_created_idx
  on public.feed_interactions (user_id, created_at desc);

create index if not exists feed_interactions_post_type_idx
  on public.feed_interactions (post_id, interaction_type, created_at desc);

create index if not exists feed_interactions_user_type_idx
  on public.feed_interactions (user_id, interaction_type, created_at desc);

-- Dedup rapid identical impressions within a short window via unique partial
-- index on (user, post, type, source, session) for impression only is too
-- aggressive across sessions; client debounce remains primary. Index for reads:
create index if not exists feed_interactions_session_idx
  on public.feed_interactions (session_id, created_at desc)
  where session_id is not null;

alter table public.feed_interactions enable row level security;

drop policy if exists "Users insert own feed interactions" on public.feed_interactions;
create policy "Users insert own feed interactions"
  on public.feed_interactions for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users read own feed interactions" on public.feed_interactions;
create policy "Users read own feed interactions"
  on public.feed_interactions for select to authenticated
  using (user_id = auth.uid());

-- No update/delete for clients — append-only analytics.

create or replace function public.record_feed_interaction(
  p_post_id uuid,
  p_interaction_type text,
  p_source_tab text default 'main',
  p_watch_time_ms integer default 0,
  p_completion_percent numeric default null,
  p_session_id text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_post_id is null then
    raise exception 'post_id required';
  end if;

  insert into public.feed_interactions (
    user_id, post_id, interaction_type, watch_time_ms,
    completion_percent, source_tab, session_id
  ) values (
    auth.uid(),
    p_post_id,
    p_interaction_type,
    greatest(coalesce(p_watch_time_ms, 0), 0),
    p_completion_percent,
    coalesce(nullif(p_source_tab, ''), 'main'),
    nullif(p_session_id, '')
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.record_feed_interaction(uuid, text, text, integer, numeric, text) from public;
grant execute on function public.record_feed_interaction(uuid, text, text, integer, numeric, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Shared eligibility helper (published / active / visible for viewer)
-- RLS still applies on direct table reads; SECURITY DEFINER RPCs re-check.
-- ---------------------------------------------------------------------------
create or replace function public.feed_post_is_eligible(p public.community_news_posts)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p.status = 'approved'
    and coalesce(p.publish_destination, 'feed') in ('feed', 'feed_and_vue')
    and (
      coalesce(p.visibility, 'public') = 'public'
      or p.author_id = auth.uid()
      or (
        coalesce(p.visibility, 'public') = 'followers'
        and auth.uid() is not null
        and exists (
          select 1 from public.profile_follows pf
          where pf.follower_id = auth.uid()
            and pf.following_id = p.author_id
        )
      )
      or (
        p.community_id is not null
        and auth.uid() is not null
        and exists (
          select 1 from public.community_members m
          where m.community_id = p.community_id
            and m.profile_id = auth.uid()
            and m.status = 'active'
        )
      )
    )
    and not exists (
      select 1 from public.feed_interactions hi
      where hi.user_id = auth.uid()
        and hi.post_id = p.id
        and hi.interaction_type in ('hide', 'not_interested', 'report')
        and hi.created_at > now() - interval '90 days'
    );
$$;

revoke all on function public.feed_post_is_eligible(public.community_news_posts) from public;
grant execute on function public.feed_post_is_eligible(public.community_news_posts)
  to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 4) New feed — reverse chronological with cursor pagination
-- ---------------------------------------------------------------------------
drop function if exists public.fetch_new_feed(integer, timestamptz, uuid);

create or replace function public.fetch_new_feed(
  p_limit integer default 20,
  p_before timestamptz default null,
  p_before_id uuid default null
)
returns table (
  id uuid,
  author_id uuid,
  business_id uuid,
  body text,
  status text,
  created_at timestamptz,
  visibility text,
  community_id uuid,
  professional_profile_id uuid,
  event_id uuid,
  background_color text,
  publish_destination text,
  feed_score double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    p.id,
    p.author_id,
    p.business_id,
    p.body,
    p.status,
    p.created_at,
    coalesce(p.visibility, 'public'),
    p.community_id,
    p.professional_profile_id,
    p.event_id,
    p.background_color,
    coalesce(p.publish_destination, 'feed'),
    extract(epoch from p.created_at)::double precision as feed_score
  from public.community_news_posts p
  where public.feed_post_is_eligible(p)
    and (
      p_before is null
      or p.created_at < p_before
      or (p.created_at = p_before and p_before_id is not null and p.id < p_before_id)
    )
  order by p.created_at desc, p.id desc
  limit greatest(1, least(coalesce(p_limit, 20), 100));
end;
$$;

revoke all on function public.fetch_new_feed(integer, timestamptz, uuid) from public;
grant execute on function public.fetch_new_feed(integer, timestamptz, uuid)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Trending feed — recent momentum (~48h) with age decay
-- trendingScore =
--   views*0.1 + likes*1 + comments*2 + saves*3 + shares*4
--   + meaningfulWatchTimeScore - ageDecay
-- ---------------------------------------------------------------------------
create or replace function public.fetch_trending_feed(
  p_limit integer default 20,
  p_window_hours integer default 48
)
returns table (
  id uuid,
  author_id uuid,
  business_id uuid,
  body text,
  status text,
  created_at timestamptz,
  visibility text,
  community_id uuid,
  professional_profile_id uuid,
  event_id uuid,
  background_color text,
  publish_destination text,
  feed_score double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_window interval := make_interval(hours => greatest(1, least(coalesce(p_window_hours, 48), 168)));
begin
  return query
  with base as (
    select
      p.*,
      extract(epoch from (now() - p.created_at)) / 3600.0 as age_hours,
      coalesce((
        select sum(imp.view_count)::integer
        from public.post_impressions imp
        where imp.post_id = p.id
          and imp.last_seen_at > now() - v_window
      ), 0) as views,
      coalesce((
        select count(*)::integer
        from public.community_news_post_sparks s
        where s.post_id = p.id
          and s.created_at > now() - v_window
      ), 0) as likes,
      coalesce((
        select count(*)::integer
        from public.feed_comments c
        where c.media_id = ('news-post:' || p.id::text)
          and c.created_at > now() - v_window
      ), 0) as comments,
      coalesce((
        select count(*)::integer
        from public.user_saved_items si
        where si.content_id = p.id::text
          and si.content_type = 'news_post'
          and si.created_at > now() - v_window
      ), 0) as saves,
      coalesce((
        select count(*)::integer
        from public.post_reposts r
        where r.original_post_id = p.id
          and r.created_at > now() - v_window
      ), 0) as shares,
      coalesce((
        select sum(fi.watch_time_ms)::bigint
        from public.feed_interactions fi
        where fi.post_id = p.id
          and fi.interaction_type = 'watch'
          and fi.created_at > now() - v_window
      ), 0) as watch_ms
    from public.community_news_posts p
    where public.feed_post_is_eligible(p)
      and p.created_at > now() - v_window * 2
  ),
  scored as (
    select
      b.*,
      (
        (b.views * 0.1)
        + (b.likes * 1.0)
        + (b.comments * 2.0)
        + (b.saves * 3.0)
        + (b.shares * 4.0)
        + (least(b.watch_ms, 120000)::double precision * 0.002)
        - ((b.age_hours / greatest(extract(epoch from v_window) / 3600.0, 1.0)) * 25.0)
      ) as score
    from base b
  )
  select
    s.id,
    s.author_id,
    s.business_id,
    s.body,
    s.status,
    s.created_at,
    coalesce(s.visibility, 'public'),
    s.community_id,
    s.professional_profile_id,
    s.event_id,
    s.background_color,
    coalesce(s.publish_destination, 'feed'),
    s.score
  from scored s
  where s.score > 0
  order by s.score desc, s.created_at desc
  limit greatest(1, least(coalesce(p_limit, 20), 100));
end;
$$;

revoke all on function public.fetch_trending_feed(integer, integer) from public;
grant execute on function public.fetch_trending_feed(integer, integer)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6) Recommended feed — rule-based personalization + cold-start fallback
-- ---------------------------------------------------------------------------
create or replace function public.fetch_recommended_feed(
  p_limit integer default 20,
  p_seed double precision default null
)
returns table (
  id uuid,
  author_id uuid,
  business_id uuid,
  body text,
  status text,
  created_at timestamptz,
  visibility text,
  community_id uuid,
  professional_profile_id uuid,
  event_id uuid,
  background_color text,
  publish_destination text,
  feed_score double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_seed double precision := coalesce(p_seed, extract(epoch from now())::double precision);
  v_uid uuid := auth.uid();
begin
  return query
  with signals as (
    select
      p.*,
      extract(epoch from (now() - p.created_at)) / 3600.0 as age_hours,
      case when v_uid is not null and exists (
        select 1 from public.profile_follows pf
        where pf.follower_id = v_uid and pf.following_id = p.author_id
      ) then 1 else 0 end as follow_hit,
      case when v_uid is not null and p.community_id is not null and exists (
        select 1 from public.community_members m
        where m.community_id = p.community_id and m.profile_id = v_uid and m.status = 'active'
      ) then 1 else 0 end as group_hit,
      case when v_uid is not null and p.community_id is not null and exists (
        select 1 from public.community_groups cg
        join public.community_hub_roles hr on hr.hub_id = cg.community_id
        where cg.group_id = p.community_id
          and cg.status in ('approved', 'approved_for_feed')
          and hr.profile_id = v_uid and hr.status = 'active'
      ) then 1 else 0 end as community_hit,
      case when v_uid is not null and p.event_id is not null and exists (
        select 1 from public.event_follows ef
        where ef.event_id = p.event_id and ef.profile_id = v_uid
      ) then 1 else 0 end as event_hit,
      case when v_uid is not null and exists (
        select 1 from public.user_saved_items si
        where si.user_id = v_uid and si.content_id = p.id::text and si.content_type = 'news_post'
      ) then 1 else 0 end as saved_hit,
      case when v_uid is not null and exists (
        select 1 from public.post_reposts r
        where r.original_post_id = p.id and r.reposter_id = v_uid
      ) then 1 else 0 end as share_hit,
      case when v_uid is not null and exists (
        select 1 from public.community_news_post_sparks s
        where s.post_id = p.id and s.user_id = v_uid
      ) then 1 else 0 end as spark_hit,
      coalesce((
        select imp.view_count from public.post_impressions imp
        where imp.user_id = v_uid and imp.post_id = p.id and imp.feed_source = 'recommended'
        limit 1
      ), 0) as seen_count,
      coalesce((
        select count(*)::integer from public.feed_interactions fi
        where fi.user_id = v_uid and fi.post_id = p.id
          and fi.interaction_type in ('skip', 'hide', 'not_interested')
          and fi.created_at > now() - interval '30 days'
      ), 0) as neg_count,
      coalesce((
        select sum(fi.watch_time_ms)::bigint from public.feed_interactions fi
        where fi.user_id = v_uid and fi.post_id = p.id and fi.interaction_type = 'watch'
      ), 0) as watch_ms,
      coalesce((
        select count(*)::integer from public.community_news_post_sparks s where s.post_id = p.id
      ), 0) as spark_count,
      coalesce((
        select count(*)::integer from public.feed_comments c
        where c.media_id = ('news-post:' || p.id::text)
      ), 0) as comment_count
    from public.community_news_posts p
    where public.feed_post_is_eligible(p)
      and p.created_at > now() - interval '21 days'
  ),
  scored as (
    select
      s.*,
      (
        (s.follow_hit * 40.0)
        + (s.group_hit * 28.0)
        + (s.community_hit * 24.0)
        + (s.event_hit * 18.0)
        + (s.saved_hit * 22.0)
        + (s.share_hit * 20.0)
        + (s.spark_hit * 8.0)
        + (least(s.watch_ms, 90000)::double precision / 90000.0 * 16.0)
        + (ln(1 + s.spark_count) * 3.0)
        + (ln(1 + s.comment_count) * 4.0)
        + (exp(-least(s.age_hours, 504) / 72.0) * 18.0)
        + ((abs(hashtext(s.id::text || v_seed::text)) % 1000) / 1000.0) * 5.0
        -- Cold-start: boost recent high-quality public content when unsigned / no signals
        + (case
             when v_uid is null then ln(1 + s.spark_count + s.comment_count) * 6.0
             when (s.follow_hit + s.group_hit + s.community_hit + s.event_hit + s.spark_hit) = 0
               then ln(1 + s.spark_count + s.comment_count) * 5.0
             else 0.0
           end)
        - (case when s.seen_count > 0 then least(36.0, 18.0 + s.seen_count * 6.0) else 0.0 end)
        - (s.neg_count * 30.0)
      ) as score
    from signals s
  ),
  ranked as (
    select
      sc.*,
      row_number() over (
        partition by sc.author_id
        order by sc.score desc, sc.created_at desc
      ) as author_rank
    from scored sc
  )
  select
    r.id,
    r.author_id,
    r.business_id,
    r.body,
    r.status,
    r.created_at,
    coalesce(r.visibility, 'public'),
    r.community_id,
    r.professional_profile_id,
    r.event_id,
    r.background_color,
    coalesce(r.publish_destination, 'feed'),
    r.score
  from ranked r
  where r.author_rank <= 2
  order by r.score desc, r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 20), 100));
end;
$$;

revoke all on function public.fetch_recommended_feed(integer, double precision) from public;
grant execute on function public.fetch_recommended_feed(integer, double precision)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7) Fix affiliation RPCs: include follows + hub membership via linked groups
-- ---------------------------------------------------------------------------
create or replace function public.fetch_profile_groups(p_profile_id uuid)
returns table (
  id uuid,
  name text,
  image_url text,
  privacy_type text,
  role text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select distinct on (c.id)
    c.id,
    c.name,
    c.image_url,
    coalesce(c.privacy_type, 'public') as privacy_type,
    case
      when c.creator_id = p_profile_id then 'Group Leader'
      when m.role is not null then initcap(replace(m.role, '_', ' '))
      when f.profile_id is not null then 'Following'
      else 'Member'
    end as role
  from public.communities c
  left join public.community_members m
    on m.community_id = c.id
   and m.profile_id = p_profile_id
   and m.status = 'active'
  left join public.community_follows f
    on f.community_id = c.id
   and f.profile_id = p_profile_id
  where (
      c.creator_id = p_profile_id
      or m.profile_id is not null
      or f.profile_id is not null
    )
    and (
      coalesce(c.privacy_type, 'public') = 'public'
      or p_profile_id = auth.uid()
      or public.is_firstvue_admin()
      or exists (
        select 1 from public.community_members viewer
        where viewer.community_id = c.id
          and viewer.profile_id = auth.uid()
          and viewer.status = 'active'
      )
    )
  order by c.id, c.name;
end;
$$;

create or replace function public.fetch_profile_communities(p_profile_id uuid)
returns table (
  id uuid,
  name text,
  image_url text,
  visibility text,
  role text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select distinct on (h.id)
    h.id,
    h.name,
    h.image_url,
    h.visibility,
    case
      when h.leader_user_id = p_profile_id
        or h.created_by_profile_id = p_profile_id then 'Community Leader'
      when r.role is not null then initcap(replace(r.role, '_', ' '))
      when e.user_id is not null then 'Community Editor'
      when linked.profile_id is not null then 'Member'
      else 'Member'
    end as role
  from public.community_hubs h
  left join public.community_hub_roles r
    on r.hub_id = h.id
   and r.profile_id = p_profile_id
   and r.status = 'active'
  left join public.community_editors e
    on e.community_id = h.id
   and e.user_id = p_profile_id
   and e.status = 'active'
  left join lateral (
    select m.profile_id
    from public.community_groups cg
    join public.community_members m
      on m.community_id = cg.group_id
     and m.profile_id = p_profile_id
     and m.status = 'active'
    where cg.community_id = h.id
      and cg.status in ('approved', 'approved_for_feed')
    limit 1
  ) linked on true
  where (
      h.created_by_profile_id = p_profile_id
      or h.leader_user_id = p_profile_id
      or r.profile_id is not null
      or e.user_id is not null
      or linked.profile_id is not null
    )
    and coalesce(h.status, 'active') in ('active', 'pending')
    and (
      h.visibility = 'public'
      or p_profile_id = auth.uid()
      or public.is_firstvue_admin()
      or exists (
        select 1 from public.community_hub_roles viewer
        where viewer.hub_id = h.id
          and viewer.profile_id = auth.uid()
          and viewer.status = 'active'
      )
      or (
        p_profile_id = auth.uid()
        and linked.profile_id is not null
      )
    )
  order by h.id, h.name;
end;
$$;

revoke all on function public.fetch_profile_groups(uuid) from public;
revoke all on function public.fetch_profile_communities(uuid) from public;
grant execute on function public.fetch_profile_groups(uuid) to authenticated, anon;
grant execute on function public.fetch_profile_communities(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- 8) Helpful indexes for ranking queries
-- ---------------------------------------------------------------------------
create index if not exists community_news_posts_feed_created_idx
  on public.community_news_posts (created_at desc, id desc)
  where status = 'approved';

create index if not exists community_news_post_sparks_created_idx
  on public.community_news_post_sparks (created_at desc);

create index if not exists post_reposts_created_idx
  on public.post_reposts (created_at desc);

-- ---------------------------------------------------------------------------
-- 9) Allow authenticated users to read business follow counts (not only own)
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated read business follows" on public.business_follows;
create policy "Authenticated read business follows"
  on public.business_follows for select to authenticated
  using (true);

