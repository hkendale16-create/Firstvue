-- FirstVue social UX: Stories, messenger unread/archive, VUE publish
-- destination, public approved reviews, hub leader invites.
-- Run in Supabase SQL Editor after prior migrations.
-- Does not weaken existing RLS.

-- ---------------------------------------------------------------------------
-- 1) Publish destination: Home feed, VUE, or both
-- ---------------------------------------------------------------------------
alter table public.community_news_posts
  add column if not exists publish_destination text;

update public.community_news_posts
set publish_destination = 'feed'
where publish_destination is null;

alter table public.community_news_posts
  alter column publish_destination set default 'feed';

do $$
begin
  alter table public.community_news_posts
    drop constraint if exists community_news_posts_publish_destination_check;
  alter table public.community_news_posts
    add constraint community_news_posts_publish_destination_check
    check (publish_destination in ('feed', 'vue', 'feed_and_vue'));
exception when others then
  null;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Saved items: VUE clips and stories
-- ---------------------------------------------------------------------------
do $$
begin
  alter table public.user_saved_items
    drop constraint if exists user_saved_items_content_type_check;
  alter table public.user_saved_items
    add constraint user_saved_items_content_type_check
    check (content_type in ('news_post', 'business', 'vue_media', 'story'));
exception when others then
  null;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Approved reviews readable by guests (write path unchanged)
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated users read approved reviews" on public.business_reviews;
drop policy if exists "Approved reviews are public" on public.business_reviews;
create policy "Approved reviews are public"
  on public.business_reviews for select to anon, authenticated
  using (status = 'approved');

-- ---------------------------------------------------------------------------
-- 4) Community creation visibility (separate from Group privacy)
-- ---------------------------------------------------------------------------
alter table public.community_creation_requests
  add column if not exists proposed_visibility text default 'public';

do $$
begin
  alter table public.community_creation_requests
    drop constraint if exists community_creation_requests_visibility_check;
  alter table public.community_creation_requests
    add constraint community_creation_requests_visibility_check
    check (proposed_visibility in ('public', 'private'));
exception when others then
  null;
end $$;

create or replace function public.review_community_creation_request(
  p_request_id uuid,
  p_approve boolean,
  p_denial_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.community_creation_requests%rowtype;
  v_hub_id uuid;
  v_admin_count integer;
  v_visibility text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_firstvue_admin() then
    raise exception 'Only FirstVue admins can review Community creation requests';
  end if;

  select * into v_req
  from public.community_creation_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_req.status <> 'pending' then
    raise exception 'Request is not pending (status=%)', v_req.status;
  end if;

  if not p_approve then
    update public.community_creation_requests
    set status = 'denied',
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        denial_reason = nullif(trim(coalesce(p_denial_reason, '')), '')
    where id = p_request_id;
    return null;
  end if;

  if v_req.requesting_user_id = auth.uid() then
    select count(*)::integer into v_admin_count
    from public.profiles
    where account_type = 'admin';
    if v_admin_count > 1 then
      raise exception
        'Another FirstVue admin must approve this Community creation request';
    end if;
  end if;

  v_visibility := case
    when coalesce(v_req.proposed_visibility, 'public') = 'private' then 'private'
    else 'public'
  end;

  begin
    insert into public.community_hubs (
      name,
      description,
      category,
      city,
      state,
      postal_code,
      created_by_profile_id,
      leader_user_id,
      status,
      creation_request_id,
      visibility
    ) values (
      v_req.proposed_name,
      v_req.description,
      v_req.category,
      v_req.city,
      v_req.state,
      v_req.postal_code,
      v_req.proposed_leader_user_id,
      v_req.proposed_leader_user_id,
      'active',
      v_req.id,
      v_visibility
    )
    returning id into v_hub_id;
  exception
    when unique_violation then
      raise exception 'A Community with this name or slug already exists';
  end;

  insert into public.community_hub_roles (hub_id, profile_id, role, status)
  values (v_hub_id, v_req.proposed_leader_user_id, 'creator', 'active')
  on conflict (hub_id, profile_id) do update
    set role = 'creator', status = 'active';

  insert into public.community_leaders (profile_id, approved_at, approved_by, status)
  values (v_req.proposed_leader_user_id, now(), auth.uid(), 'approved')
  on conflict (profile_id) do update
    set approved_at = excluded.approved_at,
        approved_by = excluded.approved_by,
        status = 'approved';

  update public.community_creation_requests
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      created_community_id = v_hub_id,
      denial_reason = null
  where id = p_request_id;

  return v_hub_id;
end;
$$;

revoke all on function public.review_community_creation_request(uuid, boolean, text) from public;
grant execute on function public.review_community_creation_request(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Secondary hub leader invite / approval (does not replace admin Community
--    creation approval)
-- ---------------------------------------------------------------------------
create or replace function public.invite_hub_leader(
  p_hub_id uuid,
  p_profile_id uuid,
  p_role text default 'leader'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(coalesce(nullif(trim(p_role), ''), 'leader'));
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if v_role not in ('leader', 'admin', 'moderator') then
    raise exception 'Invalid hub role';
  end if;
  if p_profile_id = auth.uid() then
    raise exception 'You cannot invite yourself';
  end if;

  if not (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hubs h
      where h.id = p_hub_id
        and (h.created_by_profile_id = auth.uid() or h.leader_user_id = auth.uid())
    )
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = p_hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  ) then
    raise exception 'Not authorized to invite Community leaders';
  end if;

  insert into public.community_hub_roles (hub_id, profile_id, role, status)
  values (p_hub_id, p_profile_id, v_role, 'pending')
  on conflict (hub_id, profile_id) do update
    set role = excluded.role,
        status = case
          when community_hub_roles.status = 'active' then community_hub_roles.status
          else 'pending'
        end;
end;
$$;

revoke all on function public.invite_hub_leader(uuid, uuid, text) from public;
grant execute on function public.invite_hub_leader(uuid, uuid, text) to authenticated;

create or replace function public.review_hub_role(
  p_hub_id uuid,
  p_profile_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hubs h
      where h.id = p_hub_id
        and (h.created_by_profile_id = auth.uid() or h.leader_user_id = auth.uid())
    )
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = p_hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'admin')
    )
  ) then
    raise exception 'Not authorized to review Community leaders';
  end if;

  if p_approve then
    update public.community_hub_roles
    set status = 'active'
    where hub_id = p_hub_id
      and profile_id = p_profile_id
      and status = 'pending';
  else
    update public.community_hub_roles
    set status = 'revoked'
    where hub_id = p_hub_id
      and profile_id = p_profile_id
      and status = 'pending';
  end if;
end;
$$;

revoke all on function public.review_hub_role(uuid, uuid, boolean) from public;
grant execute on function public.review_hub_role(uuid, uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Ranked Home feed: exclude VUE-only posts, return background + destination
-- ---------------------------------------------------------------------------
create or replace function public.fetch_ranked_main_feed(
  p_limit integer default 30,
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
begin
  return query
  with base as (
    select
      p.id as post_id,
      p.author_id as post_author_id,
      p.business_id as post_business_id,
      p.body as post_body,
      p.status as post_status,
      p.created_at as post_created_at,
      coalesce(p.visibility, 'public') as post_visibility,
      p.community_id as post_community_id,
      p.professional_profile_id as post_professional_profile_id,
      p.event_id as post_event_id,
      p.background_color as post_background_color,
      coalesce(p.publish_destination, 'feed') as post_publish_destination,
      extract(epoch from (now() - p.created_at)) / 3600.0 as age_hours,
      coalesce(imp.view_count, 0) as seen_count,
      imp.last_seen_at as last_seen_at,
      coalesce(spark.cnt, 0) as spark_count,
      coalesce(comment.cnt, 0) as comment_count,
      case
        when p.community_id is not null and exists (
          select 1 from public.community_members m
          where m.community_id = p.community_id
            and m.profile_id = auth.uid()
            and m.status = 'active'
        ) then 1 else 0
      end as group_affinity,
      case
        when auth.uid() is not null and exists (
          select 1 from public.profile_follows pf
          where pf.follower_id = auth.uid()
            and pf.following_id = p.author_id
        ) then 1 else 0
      end as follow_affinity
    from public.community_news_posts p
    left join public.post_impressions imp
      on imp.post_id = p.id
     and imp.user_id = auth.uid()
     and imp.feed_source = 'main'
    left join lateral (
      select count(*)::integer as cnt
      from public.community_news_post_sparks s
      where s.post_id = p.id
    ) spark on true
    left join lateral (
      select count(*)::integer as cnt
      from public.feed_comments c
      where c.media_id = ('news-post:' || p.id::text)
    ) comment on true
    where p.status = 'approved'
      and coalesce(p.visibility, 'public') = 'public'
      and coalesce(p.publish_destination, 'feed') in ('feed', 'feed_and_vue')
  ),
  scored as (
    select
      b.*,
      (
        (exp(-least(b.age_hours, 720) / 36.0) * 40.0)
        + (case when b.seen_count = 0 then 35.0
                when b.seen_count = 1 then 12.0
                else 0.0 end)
        + (b.group_affinity * 10.0)
        + (b.follow_affinity * 14.0)
        + (ln(1 + b.spark_count) * 4.0)
        + (ln(1 + b.comment_count) * 5.0)
        + (case
             when b.comment_count > 0 and b.age_hours > 24 then 8.0
             when b.spark_count > 3 and b.age_hours > 12 then 5.0
             else 0.0
           end)
        + ((abs(hashtext(b.post_id::text || v_seed::text)) % 1000) / 1000.0) * 6.0
        - (case
             when b.last_seen_at is not null
                  and b.last_seen_at > now() - interval '6 hours'
               then least(25.0, 8.0 + b.seen_count * 4.0)
             when b.seen_count >= 3 then least(18.0, b.seen_count * 3.0)
             else 0.0
           end)
      ) as score
    from base b
  )
  select
    s.post_id,
    s.post_author_id,
    s.post_business_id,
    s.post_body,
    s.post_status,
    s.post_created_at,
    s.post_visibility,
    s.post_community_id,
    s.post_professional_profile_id,
    s.post_event_id,
    s.post_background_color,
    s.post_publish_destination,
    s.score
  from scored s
  order by s.score desc, s.post_created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
end;
$$;

revoke all on function public.fetch_ranked_main_feed(integer, double precision) from public;
grant execute on function public.fetch_ranked_main_feed(integer, double precision)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7) Messenger: last-read, archive, save, reactions, optional media/replies
-- ---------------------------------------------------------------------------
create table if not exists public.direct_thread_reads (
  thread_id uuid not null references public.direct_message_threads(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  archived_at timestamptz,
  saved_at timestamptz,
  primary key (thread_id, user_id)
);

alter table public.direct_thread_reads enable row level security;

drop policy if exists "Users read own thread prefs" on public.direct_thread_reads;
create policy "Users read own thread prefs"
  on public.direct_thread_reads for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users upsert own thread prefs" on public.direct_thread_reads;
create policy "Users upsert own thread prefs"
  on public.direct_thread_reads for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users update own thread prefs" on public.direct_thread_reads;
create policy "Users update own thread prefs"
  on public.direct_thread_reads for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users delete own thread prefs" on public.direct_thread_reads;
create policy "Users delete own thread prefs"
  on public.direct_thread_reads for delete to authenticated
  using (user_id = auth.uid());

alter table public.direct_messages
  add column if not exists media_path text;
alter table public.direct_messages
  add column if not exists reply_to_id uuid;

do $$
begin
  alter table public.direct_messages
    drop constraint if exists direct_messages_body_check;
  alter table public.direct_messages
    add constraint direct_messages_body_check
    check (
      char_length(trim(body)) between 1 and 2000
      or (media_path is not null and char_length(media_path) > 0)
    );
exception when others then
  null;
end $$;

create table if not exists public.direct_message_reactions (
  message_id uuid not null references public.direct_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.direct_message_reactions enable row level security;

drop policy if exists "Participants read message reactions" on public.direct_message_reactions;
create policy "Participants read message reactions"
  on public.direct_message_reactions for select to authenticated
  using (
    exists (
      select 1
      from public.direct_messages m
      join public.direct_message_threads t on t.id = m.thread_id
      where m.id = message_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  );

drop policy if exists "Participants react to messages" on public.direct_message_reactions;
create policy "Participants react to messages"
  on public.direct_message_reactions for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.direct_messages m
      join public.direct_message_threads t on t.id = m.thread_id
      where m.id = message_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  );

drop policy if exists "Users remove own message reactions" on public.direct_message_reactions;
create policy "Users remove own message reactions"
  on public.direct_message_reactions for delete to authenticated
  using (user_id = auth.uid());

alter table public.profiles
  add column if not exists hide_read_receipts boolean not null default false;

create or replace function public.unread_direct_message_count()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(count(*)::integer, 0)
  from public.direct_messages m
  join public.direct_message_threads t on t.id = m.thread_id
  left join public.direct_thread_reads r
    on r.thread_id = t.id and r.user_id = auth.uid()
  where auth.uid() is not null
    and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    and m.sender_id <> auth.uid()
    and m.created_at > coalesce(r.last_read_at, to_timestamp(0))
    and r.archived_at is null;
$$;

revoke all on function public.unread_direct_message_count() from public;
grant execute on function public.unread_direct_message_count() to authenticated;

create or replace function public.mark_direct_thread_read(p_thread_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1 from public.direct_message_threads t
    where t.id = p_thread_id
      and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
  ) then
    raise exception 'Thread not found';
  end if;

  insert into public.direct_thread_reads (thread_id, user_id, last_read_at)
  values (p_thread_id, auth.uid(), now())
  on conflict (thread_id, user_id)
  do update set last_read_at = now();
end;
$$;

revoke all on function public.mark_direct_thread_read(uuid) from public;
grant execute on function public.mark_direct_thread_read(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Stories (24h, multi-entity, reuse profile-media storage)
-- ---------------------------------------------------------------------------
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null
    check (entity_type in (
      'user', 'business', 'professional', 'community', 'group', 'event'
    )),
  entity_id uuid not null,
  media_path text not null,
  media_kind text not null check (media_kind in ('image', 'video')),
  caption text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);

create index if not exists stories_owner_expires_idx
  on public.stories (owner_id, expires_at desc);
create index if not exists stories_entity_expires_idx
  on public.stories (entity_type, entity_id, expires_at desc);
create index if not exists stories_expires_idx
  on public.stories (expires_at);

create table if not exists public.story_views (
  story_id uuid not null references public.stories(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  viewed_at timestamptz not null default now(),
  primary key (story_id, viewer_id)
);

create table if not exists public.story_reactions (
  story_id uuid not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null default 'spark',
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);

alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.story_reactions enable row level security;

drop policy if exists "Anyone reads unexpired or own stories" on public.stories;
create policy "Anyone reads unexpired or own stories"
  on public.stories for select to anon, authenticated
  using (expires_at > now() or owner_id = auth.uid());

drop policy if exists "Owners create stories" on public.stories;
create policy "Owners create stories"
  on public.stories for insert to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "Owners delete own stories" on public.stories;
create policy "Owners delete own stories"
  on public.stories for delete to authenticated
  using (owner_id = auth.uid());

drop policy if exists "Owners read story views" on public.story_views;
create policy "Owners read story views"
  on public.story_views for select to authenticated
  using (
    viewer_id = auth.uid()
    or exists (
      select 1 from public.stories s
      where s.id = story_id and s.owner_id = auth.uid()
    )
  );

drop policy if exists "Users record own story views" on public.story_views;
create policy "Users record own story views"
  on public.story_views for insert to authenticated
  with check (viewer_id = auth.uid());

drop policy if exists "Anyone reads story reactions" on public.story_reactions;
create policy "Anyone reads story reactions"
  on public.story_reactions for select to anon, authenticated
  using (true);

drop policy if exists "Users react to stories" on public.story_reactions;
create policy "Users react to stories"
  on public.story_reactions for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users remove own story reactions" on public.story_reactions;
create policy "Users remove own story reactions"
  on public.story_reactions for delete to authenticated
  using (user_id = auth.uid());
