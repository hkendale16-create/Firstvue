-- =============================================================================
-- FirstVue — Community Editors, creation approval, Group publishing rights,
-- Community feed references, post impressions, and ranked main feed.
-- Extends 20260829_community_hubs_and_group_leadership.sql (non-destructive).
-- Groups remain in public.communities; umbrella Communities are community_hubs.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Community hubs: one designated leader + cover + status
-- ---------------------------------------------------------------------------
alter table public.community_hubs
  add column if not exists leader_user_id uuid references public.profiles(id) on delete restrict,
  add column if not exists cover_url text,
  add column if not exists status text not null default 'active'
    check (status in ('pending', 'active', 'suspended', 'archived')),
  add column if not exists creation_request_id uuid;

update public.community_hubs
set leader_user_id = coalesce(leader_user_id, created_by_profile_id)
where leader_user_id is null;

create index if not exists community_hubs_leader_idx
  on public.community_hubs (leader_user_id);

create index if not exists community_hubs_status_idx
  on public.community_hubs (status, created_at desc);

-- ---------------------------------------------------------------------------
-- 2) Community creation requests (admin-gated Community creation)
-- ---------------------------------------------------------------------------
create table if not exists public.community_creation_requests (
  id uuid primary key default gen_random_uuid(),
  requesting_user_id uuid not null references public.profiles(id) on delete cascade,
  proposed_name text not null,
  description text,
  category text,
  city text,
  state text,
  postal_code text,
  location_label text,
  proposed_leader_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'denied', 'cancelled')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  denial_reason text,
  created_community_id uuid references public.community_hubs(id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists community_creation_requests_one_pending_name_idx
  on public.community_creation_requests (lower(proposed_name))
  where status = 'pending';

create index if not exists community_creation_requests_status_idx
  on public.community_creation_requests (status, created_at desc);

create index if not exists community_creation_requests_requester_idx
  on public.community_creation_requests (requesting_user_id, created_at desc);

alter table public.community_creation_requests enable row level security;

drop policy if exists "Users create community creation requests" on public.community_creation_requests;
create policy "Users create community creation requests"
  on public.community_creation_requests for insert to authenticated
  with check (
    requesting_user_id = auth.uid()
    and proposed_leader_user_id = auth.uid()
  );

drop policy if exists "Users read own community creation requests" on public.community_creation_requests;
create policy "Users read own community creation requests"
  on public.community_creation_requests for select to authenticated
  using (
    requesting_user_id = auth.uid()
    or public.is_firstvue_admin()
  );

drop policy if exists "Users cancel own pending community creation requests" on public.community_creation_requests;
create policy "Users cancel own pending community creation requests"
  on public.community_creation_requests for delete to authenticated
  using (requesting_user_id = auth.uid() and status = 'pending');

drop policy if exists "Admins manage community creation requests" on public.community_creation_requests;
create policy "Admins manage community creation requests"
  on public.community_creation_requests for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- Block direct hub inserts by normal users (only via admin approve RPC /
-- FirstVue admin). The review RPC is SECURITY DEFINER and bypasses RLS.
drop policy if exists "Approved leaders create community hubs" on public.community_hubs;
drop policy if exists "Admins or approve-RPC create community hubs" on public.community_hubs;
create policy "Only admins insert community hubs directly"
  on public.community_hubs for insert to authenticated
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- 3) Community Editors (max 6 active) + granular permissions
-- ---------------------------------------------------------------------------
create table if not exists public.community_editors (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.community_hubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  permissions jsonb not null default '{}'::jsonb,
  added_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (community_id, user_id)
);

-- Known permission keys (enforced in app + RPCs):
-- approve_group_requests, deny_group_requests, add_groups, remove_groups,
-- moderate_content, manage_newsfeed, approve_group_posting, revoke_group_posting

create index if not exists community_editors_community_active_idx
  on public.community_editors (community_id)
  where status = 'active';

alter table public.community_editors enable row level security;

create or replace function public.is_community_leader(p_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.community_hubs h
    where h.id = p_community_id
      and h.leader_user_id = auth.uid()
      and h.status = 'active'
  )
  or exists (
    select 1 from public.community_hub_roles r
    where r.hub_id = p_community_id
      and r.profile_id = auth.uid()
      and r.status = 'active'
      and r.role in ('creator', 'lead_leader', 'leader')
  )
  or public.is_firstvue_admin();
$$;

revoke all on function public.is_community_leader(uuid) from public;
grant execute on function public.is_community_leader(uuid) to authenticated;

create or replace function public.community_editor_has_permission(
  p_community_id uuid,
  p_permission text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_community_leader(p_community_id)
    or exists (
      select 1 from public.community_editors e
      where e.community_id = p_community_id
        and e.user_id = auth.uid()
        and e.status = 'active'
        and coalesce((e.permissions ->> p_permission)::boolean, false) = true
    );
$$;

revoke all on function public.community_editor_has_permission(uuid, text) from public;
grant execute on function public.community_editor_has_permission(uuid, text) to authenticated;

create or replace function public.enforce_community_editor_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_count integer;
begin
  if new.status = 'active' then
    select count(*)::integer into active_count
    from public.community_editors
    where community_id = new.community_id
      and status = 'active'
      and user_id <> new.user_id;

    if active_count >= 6 then
      raise exception 'A Community may have at most 6 active Editors';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_community_editor_limit on public.community_editors;
create trigger trg_community_editor_limit
  before insert or update of status on public.community_editors
  for each row execute function public.enforce_community_editor_limit();

-- Editors cannot raise their own permissions or appoint themselves.
create or replace function public.enforce_community_editor_self_service()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.user_id = auth.uid() and not public.is_firstvue_admin() then
      raise exception 'Editors cannot appoint themselves';
    end if;
    if not public.is_community_leader(new.community_id) then
      raise exception 'Only the Community Leader can appoint Editors';
    end if;
  elsif tg_op = 'UPDATE' then
    if new.user_id = auth.uid()
       and new.permissions is distinct from old.permissions
       and not public.is_community_leader(new.community_id)
       and not public.is_firstvue_admin() then
      raise exception 'Editors cannot grant themselves additional privileges';
    end if;
    if new.user_id = auth.uid()
       and new.status = 'active'
       and old.status <> 'active'
       and not public.is_community_leader(new.community_id)
       and not public.is_firstvue_admin() then
      raise exception 'Editors cannot reactivate themselves';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_community_editor_self_service on public.community_editors;
create trigger trg_community_editor_self_service
  before insert or update on public.community_editors
  for each row execute function public.enforce_community_editor_self_service();

drop policy if exists "Authenticated read community editors" on public.community_editors;
create policy "Authenticated read community editors"
  on public.community_editors for select to authenticated using (true);

drop policy if exists "Leaders manage community editors" on public.community_editors;
create policy "Leaders manage community editors"
  on public.community_editors for all to authenticated
  using (public.is_community_leader(community_id))
  with check (public.is_community_leader(community_id));

-- ---------------------------------------------------------------------------
-- 4) Community ↔ Group membership with publishing permission
-- ---------------------------------------------------------------------------
create table if not exists public.community_groups (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.community_hubs(id) on delete cascade,
  group_id uuid not null references public.communities(id) on delete cascade,
  status text not null default 'pending'
    check (status in (
      'pending',
      'approved',
      'approved_for_feed',
      'suspended',
      'removed',
      'denied'
    )),
  can_post_to_community_feed boolean not null default false,
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  posting_approved_by uuid references public.profiles(id) on delete set null,
  posting_approved_at timestamptz,
  posting_suspended_at timestamptz,
  removed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (community_id, group_id)
);

create index if not exists community_groups_community_status_idx
  on public.community_groups (community_id, status);

create index if not exists community_groups_group_idx
  on public.community_groups (group_id);

alter table public.community_groups enable row level security;

-- Keep hub_id in sync when a group is approved into a community.
create or replace function public.sync_group_hub_id_from_community_groups()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    if new.status in ('approved', 'approved_for_feed') and new.removed_at is null then
      update public.communities
      set hub_id = new.community_id, updated_at = now()
      where id = new.group_id;
    elsif new.status in ('removed', 'denied', 'suspended') then
      update public.communities
      set hub_id = null, updated_at = now()
      where id = new.group_id and hub_id = new.community_id;
      -- Removing/suspending membership also clears feed publishing.
      new.can_post_to_community_feed := false;
    end if;
    if new.can_post_to_community_feed = true
       and new.status not in ('approved', 'approved_for_feed') then
      raise exception 'Group must be an approved Community Group before feed publishing';
    end if;
    if new.can_post_to_community_feed = true and new.status = 'approved' then
      new.status := 'approved_for_feed';
    end if;
    if new.can_post_to_community_feed = false and new.status = 'approved_for_feed' then
      new.status := 'approved';
    end if;
    return new;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_group_hub_id on public.community_groups;
create trigger trg_sync_group_hub_id
  before insert or update on public.community_groups
  for each row execute function public.sync_group_hub_id_from_community_groups();

drop policy if exists "Authenticated read community groups" on public.community_groups;
create policy "Authenticated read community groups"
  on public.community_groups for select to authenticated
  using (
    status in ('approved', 'approved_for_feed', 'pending', 'suspended')
    or public.is_community_leader(community_id)
    or public.community_editor_has_permission(community_id, 'add_groups')
    or exists (
      select 1 from public.communities c
      where c.id = group_id and c.creator_id = auth.uid()
    )
  );

drop policy if exists "Authorized insert community groups" on public.community_groups;
create policy "Authorized insert community groups"
  on public.community_groups for insert to authenticated
  with check (
    public.is_community_leader(community_id)
    or public.community_editor_has_permission(community_id, 'add_groups')
    or (
      status = 'pending'
      and exists (
        select 1 from public.communities c
        where c.id = group_id
          and (
            c.creator_id = auth.uid()
            or exists (
              select 1 from public.community_members m
              where m.community_id = c.id
                and m.profile_id = auth.uid()
                and m.status = 'active'
                and m.role in ('owner', 'admin')
            )
          )
      )
    )
  );

drop policy if exists "Authorized update community groups" on public.community_groups;
create policy "Authorized update community groups"
  on public.community_groups for update to authenticated
  using (
    public.is_community_leader(community_id)
    or public.community_editor_has_permission(community_id, 'approve_group_requests')
    or public.community_editor_has_permission(community_id, 'remove_groups')
    or public.community_editor_has_permission(community_id, 'approve_group_posting')
    or public.community_editor_has_permission(community_id, 'revoke_group_posting')
  )
  with check (true);

-- ---------------------------------------------------------------------------
-- 5) Community feed references (point at Group posts; soft-remove only)
-- ---------------------------------------------------------------------------
create table if not exists public.community_feed_posts (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.community_hubs(id) on delete cascade,
  group_id uuid not null references public.communities(id) on delete cascade,
  source_post_id uuid not null references public.community_news_posts(id) on delete cascade,
  shared_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  removed_from_community_at timestamptz,
  removed_by uuid references public.profiles(id) on delete set null,
  unique (community_id, source_post_id)
);

create index if not exists community_feed_posts_community_created_idx
  on public.community_feed_posts (community_id, created_at desc)
  where removed_from_community_at is null;

create index if not exists community_feed_posts_source_idx
  on public.community_feed_posts (source_post_id);

alter table public.community_feed_posts enable row level security;

drop policy if exists "Authenticated read community feed posts" on public.community_feed_posts;
create policy "Authenticated read community feed posts"
  on public.community_feed_posts for select to authenticated
  using (
    removed_from_community_at is null
    or public.is_community_leader(community_id)
    or public.community_editor_has_permission(community_id, 'manage_newsfeed')
  );

-- Inserts happen via trigger/RPC when an approved Group publishes.
drop policy if exists "System insert community feed posts" on public.community_feed_posts;
create policy "System insert community feed posts"
  on public.community_feed_posts for insert to authenticated
  with check (
    exists (
      select 1 from public.community_groups cg
      where cg.community_id = community_feed_posts.community_id
        and cg.group_id = community_feed_posts.group_id
        and cg.can_post_to_community_feed = true
        and cg.status in ('approved', 'approved_for_feed')
    )
    and exists (
      select 1 from public.community_news_posts p
      where p.id = source_post_id
        and p.community_id = group_id
        and p.author_id = auth.uid()
    )
  );

drop policy if exists "Leaders soft-remove community feed posts" on public.community_feed_posts;
create policy "Leaders soft-remove community feed posts"
  on public.community_feed_posts for update to authenticated
  using (
    public.is_community_leader(community_id)
    or public.community_editor_has_permission(community_id, 'manage_newsfeed')
    or public.community_editor_has_permission(community_id, 'moderate_content')
  )
  with check (true);

-- Auto-publish Group posts into Community feed when Group has publishing rights.
create or replace function public.publish_group_post_to_community_feed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_link public.community_groups%rowtype;
begin
  if new.community_id is null then
    return new;
  end if;

  select * into v_link
  from public.community_groups cg
  where cg.group_id = new.community_id
    and cg.can_post_to_community_feed = true
    and cg.status in ('approved', 'approved_for_feed')
    and cg.removed_at is null
  order by cg.created_at desc
  limit 1;

  if not found then
    return new;
  end if;

  insert into public.community_feed_posts (
    community_id, group_id, source_post_id, shared_by
  ) values (
    v_link.community_id, new.community_id, new.id, new.author_id
  )
  on conflict (community_id, source_post_id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_publish_group_post_to_community_feed on public.community_news_posts;
create trigger trg_publish_group_post_to_community_feed
  after insert on public.community_news_posts
  for each row execute function public.publish_group_post_to_community_feed();

-- ---------------------------------------------------------------------------
-- 6) Group posting: only active members may insert posts into a Group
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated users post news" on public.community_news_posts;
create policy "Authenticated users post news"
  on public.community_news_posts for insert to authenticated
  with check (
    author_id = auth.uid()
    and (
      community_id is null
      or exists (
        select 1 from public.community_members m
        where m.community_id = community_news_posts.community_id
          and m.profile_id = auth.uid()
          and m.status = 'active'
      )
      or exists (
        select 1 from public.communities c
        where c.id = community_news_posts.community_id
          and c.creator_id = auth.uid()
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 7) Approve Community creation request → create hub + assign Leader
-- ---------------------------------------------------------------------------
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
begin
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
    raise exception 'Request is not pending';
  end if;

  if not p_approve then
    update public.community_creation_requests
    set status = 'denied',
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        denial_reason = p_denial_reason
    where id = p_request_id;
    return null;
  end if;

  -- Ensure requester cannot approve themselves via forged admin flag alone —
  -- is_firstvue_admin() already required above. Also refuse self-review.
  if v_req.requesting_user_id = auth.uid() then
    raise exception 'Users cannot approve their own Community creation request';
  end if;

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
    'public'
  )
  returning id into v_hub_id;

  insert into public.community_hub_roles (hub_id, profile_id, role, status)
  values (v_hub_id, v_req.proposed_leader_user_id, 'creator', 'active')
  on conflict (hub_id, profile_id) do update
    set role = 'creator', status = 'active';

  -- Mark requester as an approved community leader for continuity with older flows.
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
      created_community_id = v_hub_id
  where id = p_request_id;

  return v_hub_id;
end;
$$;

revoke all on function public.review_community_creation_request(uuid, boolean, text) from public;
grant execute on function public.review_community_creation_request(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) Post impressions (visible-only tracking)
-- ---------------------------------------------------------------------------
create table if not exists public.post_impressions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  view_count integer not null default 1,
  view_duration_ms integer not null default 0,
  feed_source text not null default 'main'
    check (feed_source in ('main', 'group', 'community', 'profile', 'vue', 'other')),
  created_at timestamptz not null default now(),
  unique (user_id, post_id, feed_source)
);

create index if not exists post_impressions_user_last_seen_idx
  on public.post_impressions (user_id, last_seen_at desc);

create index if not exists post_impressions_post_idx
  on public.post_impressions (post_id);

alter table public.post_impressions enable row level security;

drop policy if exists "Users manage own post impressions" on public.post_impressions;
create policy "Users manage own post impressions"
  on public.post_impressions for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.record_post_impression(
  p_post_id uuid,
  p_feed_source text default 'main',
  p_view_duration_ms integer default 0
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

  insert into public.post_impressions (
    user_id, post_id, feed_source, view_duration_ms, view_count
  ) values (
    auth.uid(),
    p_post_id,
    coalesce(nullif(p_feed_source, ''), 'main'),
    greatest(coalesce(p_view_duration_ms, 0), 0),
    1
  )
  on conflict (user_id, post_id, feed_source) do update
    set last_seen_at = now(),
        view_count = public.post_impressions.view_count + 1,
        view_duration_ms = public.post_impressions.view_duration_ms
          + greatest(coalesce(p_view_duration_ms, 0), 0);
end;
$$;

revoke all on function public.record_post_impression(uuid, text, integer) from public;
grant execute on function public.record_post_impression(uuid, text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 9) Ranked main Newsfeed (recency + unseen + relevance + controlled variance)
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
        when exists (
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
    s.score
  from scored s
  order by s.score desc, s.post_created_at desc
  limit greatest(1, least(coalesce(p_limit, 30), 100));
end;
$$;

revoke all on function public.fetch_ranked_main_feed(integer, double precision) from public;
grant execute on function public.fetch_ranked_main_feed(integer, double precision) to authenticated;

-- ---------------------------------------------------------------------------
-- 10) Helper: set Group community-feed posting permission
-- ---------------------------------------------------------------------------
create or replace function public.set_group_community_feed_posting(
  p_community_id uuid,
  p_group_id uuid,
  p_allow boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    public.is_community_leader(p_community_id)
    or (
      p_allow and public.community_editor_has_permission(p_community_id, 'approve_group_posting')
    )
    or (
      not p_allow and public.community_editor_has_permission(p_community_id, 'revoke_group_posting')
    )
  ) then
    raise exception 'Not authorized to change Community feed posting permission';
  end if;

  update public.community_groups
  set
    can_post_to_community_feed = p_allow,
    status = case
      when p_allow then 'approved_for_feed'
      when status = 'removed' then status
      when status = 'suspended' then status
      else 'approved'
    end,
    posting_approved_by = case when p_allow then auth.uid() else posting_approved_by end,
    posting_approved_at = case when p_allow then now() else posting_approved_at end,
    posting_suspended_at = case when p_allow then null else now() end
  where community_id = p_community_id
    and group_id = p_group_id
    and status in ('approved', 'approved_for_feed', 'suspended');

  if not found then
    raise exception 'Group is not an approved member of this Community';
  end if;
end;
$$;

revoke all on function public.set_group_community_feed_posting(uuid, uuid, boolean) from public;
grant execute on function public.set_group_community_feed_posting(uuid, uuid, boolean) to authenticated;
