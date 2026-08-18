-- =============================================================================
-- VUE reel engagement summaries (minimal, reuse existing tables)
--
-- Why this exists:
--   The VUE mosaic previously had no public like/view/play counts. Existing
--   feed_engagements rows are insert-only, RLS-private to the actor, and
--   media_id is a UUID FK to business_media — so profile media and news posts
--   cannot record there. Comments already use text media_id (including
--   'news-post:<uuid>').
--
-- This migration:
--   1) Lets feed_engagements store any VUE media key (text, no business FK).
--   2) Adds a 'play' event distinct from unique 'view'.
--   3) Enforces one like row per (user, media) so toggles cannot inflate.
--   4) Adds two RPCs so the client hydrates a page of VUE items in ONE round
--      trip instead of N queries per visible tile.
--
-- Does not create a new analytics warehouse, hashtag table, or realtime fanout.
-- =============================================================================

alter table public.feed_engagements
  drop constraint if exists feed_engagements_media_id_fkey;

alter table public.feed_engagements
  alter column media_id type text using media_id::text;

alter table public.feed_engagements
  drop constraint if exists feed_engagements_event_type_check;

alter table public.feed_engagements
  add constraint feed_engagements_event_type_check
  check (event_type in (
    'impression', 'view', 'like', 'save', 'share',
    'profile_tap', 'booking_tap', 'play'
  ));

create index if not exists feed_engagements_media_type_idx
  on public.feed_engagements (media_id, event_type, created_at desc);

create index if not exists feed_engagements_profile_media_type_idx
  on public.feed_engagements (profile_id, media_id, event_type, created_at desc);

create unique index if not exists feed_engagements_like_unique
  on public.feed_engagements (profile_id, media_id)
  where event_type = 'like';

create or replace function public.vue_comment_key(
  p_media_id text,
  p_news_post_id uuid
)
returns text
language sql
immutable
as $$
  select case
    when p_news_post_id is not null then 'news-post:' || p_news_post_id::text
    else p_media_id
  end;
$$;

-- ---------------------------------------------------------------------------
-- Batch summary for a VUE page. Returns one row per requested media_id.
-- Counts are aggregates only (no actor identities). Viewer flags use auth.uid().
-- ---------------------------------------------------------------------------
create or replace function public.fetch_vue_engagement_summaries(
  p_media_ids text[],
  p_news_post_ids text[] default '{}'
)
returns table (
  media_id text,
  likes_count integer,
  comments_count integer,
  shares_count integer,
  saves_count integer,
  views_count integer,
  plays_count integer,
  recent_likes integer,
  recent_comments integer,
  recent_shares integer,
  recent_saves integer,
  recent_views integer,
  recent_plays integer,
  user_has_liked boolean,
  user_has_saved boolean,
  my_reaction text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_window interval := interval '48 hours';
  v_uid uuid := auth.uid();
begin
  if p_media_ids is null or cardinality(p_media_ids) = 0 then
    return;
  end if;

  return query
  with requested as (
    select
      m.media_id,
      m.ord,
      nullif(coalesce(p.news_post_id, ''), '')::uuid as news_post_id,
      public.vue_comment_key(
        m.media_id,
        nullif(coalesce(p.news_post_id, ''), '')::uuid
      ) as comment_key,
      coalesce(nullif(p.news_post_id, ''), m.media_id) as save_id,
      case
        when nullif(coalesce(p.news_post_id, ''), '') is not null
          then 'news_post'
        else 'vue_media'
      end as save_type
    from unnest(p_media_ids) with ordinality as m(media_id, ord)
    left join unnest(coalesce(p_news_post_ids, '{}'::text[]))
      with ordinality as p(news_post_id, ord)
      on p.ord = m.ord
  ),
  comment_stats as (
    select
      c.media_id,
      count(*)::integer as total,
      count(*) filter (where c.created_at > now() - v_window)::integer as recent
    from public.feed_comments c
    where c.media_id in (select r.comment_key from requested r)
    group by c.media_id
  ),
  spark_stats as (
    select
      s.post_id,
      count(*)::integer as total,
      count(*) filter (where s.created_at > now() - v_window)::integer as recent,
      max(case when v_uid is not null and s.user_id = v_uid then s.reaction_type end)
        as my_reaction
    from public.community_news_post_sparks s
    where s.post_id in (select r.news_post_id from requested r where r.news_post_id is not null)
    group by s.post_id
  ),
  eng_stats as (
    select
      e.media_id,
      count(*) filter (where e.event_type = 'like')::integer as likes,
      count(*) filter (
        where e.event_type = 'like' and e.created_at > now() - v_window
      )::integer as recent_likes,
      count(*) filter (where e.event_type = 'share')::integer as shares,
      count(*) filter (
        where e.event_type = 'share' and e.created_at > now() - v_window
      )::integer as recent_shares,
      count(distinct e.profile_id) filter (where e.event_type = 'view')::integer
        as views,
      count(distinct e.profile_id) filter (
        where e.event_type = 'view' and e.created_at > now() - v_window
      )::integer as recent_views,
      count(*) filter (where e.event_type = 'play')::integer as plays,
      count(*) filter (
        where e.event_type = 'play' and e.created_at > now() - v_window
      )::integer as recent_plays,
      bool_or(v_uid is not null and e.profile_id = v_uid and e.event_type = 'like')
        as liked
    from public.feed_engagements e
    where e.media_id in (select r.media_id from requested r)
    group by e.media_id
  ),
  save_stats as (
    select
      s.content_id,
      s.content_type,
      count(*)::integer as total,
      count(*) filter (where s.created_at > now() - v_window)::integer as recent,
      bool_or(v_uid is not null and s.user_id = v_uid) as saved
    from public.user_saved_items s
    where (s.content_type, s.content_id) in (
      select r.save_type, r.save_id from requested r
    )
    group by s.content_id, s.content_type
  )
  select
    r.media_id,
    coalesce(
      case when r.news_post_id is not null then sp.total else en.likes end,
      0
    ) as likes_count,
    coalesce(cs.total, 0) as comments_count,
    coalesce(en.shares, 0) as shares_count,
    coalesce(sv.total, 0) as saves_count,
    coalesce(en.views, 0) as views_count,
    coalesce(en.plays, 0) as plays_count,
    coalesce(
      case when r.news_post_id is not null then sp.recent else en.recent_likes end,
      0
    ) as recent_likes,
    coalesce(cs.recent, 0) as recent_comments,
    coalesce(en.recent_shares, 0) as recent_shares,
    coalesce(sv.recent, 0) as recent_saves,
    coalesce(en.recent_views, 0) as recent_views,
    coalesce(en.recent_plays, 0) as recent_plays,
    coalesce(
      case
        when r.news_post_id is not null then sp.my_reaction is not null
        else en.liked
      end,
      false
    ) as user_has_liked,
    coalesce(sv.saved, false) as user_has_saved,
    sp.my_reaction as my_reaction
  from requested r
  left join comment_stats cs on cs.media_id = r.comment_key
  left join spark_stats sp on sp.post_id = r.news_post_id
  left join eng_stats en on en.media_id = r.media_id
  left join save_stats sv
    on sv.content_id = r.save_id and sv.content_type = r.save_type
  order by r.ord;
end;
$$;

revoke all on function public.fetch_vue_engagement_summaries(text[], text[]) from public;
grant execute on function public.fetch_vue_engagement_summaries(text[], text[])
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Record a legitimate VUE interaction. Dedupes views (24h / user / media) and
-- plays (30s / user / media) so widget rebuilds cannot inflate counts.
-- Like is a toggle against the unique (profile, media) like row.
-- ---------------------------------------------------------------------------
create or replace function public.record_vue_engagement(
  p_media_id text,
  p_event_type text,
  p_news_post_id uuid default null,
  p_watch_ms integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_type text := lower(trim(coalesce(p_event_type, '')));
  v_media text := trim(coalesce(p_media_id, ''));
  v_inserted boolean := false;
  v_liked boolean := false;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if v_media = '' then
    raise exception 'media_id required';
  end if;
  if v_type not in ('view', 'play', 'like', 'share', 'save', 'impression') then
    raise exception 'Unsupported VUE engagement type';
  end if;

  if v_type = 'like' then
    delete from public.feed_engagements
    where profile_id = v_uid
      and media_id = v_media
      and event_type = 'like';
    if found then
      v_liked := false;
    else
      insert into public.feed_engagements (profile_id, media_id, event_type, watch_ms)
      values (v_uid, v_media, 'like', greatest(coalesce(p_watch_ms, 0), 0));
      v_liked := true;
    end if;
    v_inserted := v_liked;
  elsif v_type = 'view' then
    if not exists (
      select 1 from public.feed_engagements
      where profile_id = v_uid
        and media_id = v_media
        and event_type = 'view'
        and created_at > now() - interval '24 hours'
    ) then
      insert into public.feed_engagements (profile_id, media_id, event_type, watch_ms)
      values (v_uid, v_media, 'view', greatest(coalesce(p_watch_ms, 0), 0));
      v_inserted := true;
    end if;
  elsif v_type = 'play' then
    if not exists (
      select 1 from public.feed_engagements
      where profile_id = v_uid
        and media_id = v_media
        and event_type = 'play'
        and created_at > now() - interval '30 seconds'
    ) then
      insert into public.feed_engagements (profile_id, media_id, event_type, watch_ms)
      values (v_uid, v_media, 'play', greatest(coalesce(p_watch_ms, 0), 0));
      v_inserted := true;
    end if;
  else
    insert into public.feed_engagements (profile_id, media_id, event_type, watch_ms)
    values (v_uid, v_media, v_type, greatest(coalesce(p_watch_ms, 0), 0));
    v_inserted := true;
  end if;

  return jsonb_build_object(
    'recorded', v_inserted,
    'user_has_liked', v_liked
  );
end;
$$;

revoke all on function public.record_vue_engagement(text, text, uuid, integer) from public;
grant execute on function public.record_vue_engagement(text, text, uuid, integer)
  to authenticated;
