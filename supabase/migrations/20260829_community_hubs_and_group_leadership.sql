-- Community hubs (umbrella Communities) vs Groups (existing public.communities)
-- Groups remain in public.communities; hubs are parent local Communities.

-- ---------------------------------------------------------------------------
-- Approved Community Leaders (gate for creating hubs)
-- ---------------------------------------------------------------------------
create table if not exists public.community_leaders (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  approved_at timestamptz not null default now(),
  approved_by uuid references public.profiles(id) on delete set null,
  status text not null default 'approved'
    check (status in ('approved', 'revoked', 'suspended'))
);

alter table public.community_leaders enable row level security;

drop policy if exists "Users read own community leader status" on public.community_leaders;
create policy "Users read own community leader status"
  on public.community_leaders for select to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin());

drop policy if exists "Admins manage community leaders" on public.community_leaders;
create policy "Admins manage community leaders"
  on public.community_leaders for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

create or replace function public.is_approved_community_leader()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.community_leaders cl
    where cl.profile_id = auth.uid()
      and cl.status = 'approved'
  );
$$;

revoke all on function public.is_approved_community_leader() from public;
grant execute on function public.is_approved_community_leader() to authenticated;

-- ---------------------------------------------------------------------------
-- Community Leader access requests
-- ---------------------------------------------------------------------------
create table if not exists public.community_leader_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  requested_city text,
  requested_state text,
  requested_location text,
  reason text,
  experience text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'declined', 'revoked', 'suspended')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);

create unique index if not exists community_leader_requests_one_pending_idx
  on public.community_leader_requests (profile_id)
  where status = 'pending';

create index if not exists community_leader_requests_status_idx
  on public.community_leader_requests (status, created_at desc);

alter table public.community_leader_requests enable row level security;

drop policy if exists "Users create community leader requests" on public.community_leader_requests;
create policy "Users create community leader requests"
  on public.community_leader_requests for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users read own community leader requests" on public.community_leader_requests;
create policy "Users read own community leader requests"
  on public.community_leader_requests for select to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin());

drop policy if exists "Users cancel own pending community leader requests" on public.community_leader_requests;
create policy "Users cancel own pending community leader requests"
  on public.community_leader_requests for delete to authenticated
  using (profile_id = auth.uid() and status = 'pending');

drop policy if exists "Admins manage community leader requests" on public.community_leader_requests;
create policy "Admins manage community leader requests"
  on public.community_leader_requests for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- Community hubs (umbrella Communities that contain many Groups)
-- ---------------------------------------------------------------------------
create table if not exists public.community_hubs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text,
  description text,
  image_url text,
  category text,
  city text,
  state text,
  postal_code text,
  country_code text not null default 'US',
  latitude double precision,
  longitude double precision,
  rules text,
  visibility text not null default 'public'
    check (visibility in ('public', 'private')),
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  follower_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists community_hubs_slug_uidx
  on public.community_hubs (slug)
  where slug is not null;

create index if not exists community_hubs_location_idx
  on public.community_hubs (state, city);

alter table public.community_hubs enable row level security;

-- ---------------------------------------------------------------------------
-- Hub leadership roles (supports multiple leaders)
-- ---------------------------------------------------------------------------
create table if not exists public.community_hub_roles (
  hub_id uuid not null references public.community_hubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'leader'
    check (role in ('creator', 'lead_leader', 'leader', 'admin', 'moderator')),
  status text not null default 'active'
    check (status in ('active', 'pending', 'revoked')),
  created_at timestamptz not null default now(),
  primary key (hub_id, profile_id)
);

create index if not exists community_hub_roles_profile_idx
  on public.community_hub_roles (profile_id, status);

alter table public.community_hub_roles enable row level security;

drop policy if exists "Authenticated read hub roles" on public.community_hub_roles;
create policy "Authenticated read hub roles"
  on public.community_hub_roles for select to authenticated using (true);

drop policy if exists "Users insert own creator hub role" on public.community_hub_roles;
create policy "Users insert own creator hub role"
  on public.community_hub_roles for insert to authenticated
  with check (
    profile_id = auth.uid()
    and role = 'creator'
    and exists (
      select 1 from public.community_hubs h
      where h.id = hub_id
        and h.created_by_profile_id = auth.uid()
    )
  );

drop policy if exists "Hub creators manage hub roles" on public.community_hub_roles;
create policy "Hub creators manage hub roles"
  on public.community_hub_roles for all to authenticated
  using (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hubs h
      where h.id = community_hub_roles.hub_id
        and h.created_by_profile_id = auth.uid()
    )
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_hub_roles.hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  )
  with check (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hubs h
      where h.id = community_hub_roles.hub_id
        and h.created_by_profile_id = auth.uid()
    )
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_hub_roles.hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  );

-- Hub policies (after roles table exists)
drop policy if exists "Authenticated read public community hubs" on public.community_hubs;
create policy "Authenticated read public community hubs"
  on public.community_hubs for select to authenticated
  using (
    visibility = 'public'
    or created_by_profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_hubs.id
        and r.profile_id = auth.uid()
        and r.status = 'active'
    )
  );

drop policy if exists "Approved leaders create community hubs" on public.community_hubs;
create policy "Approved leaders create community hubs"
  on public.community_hubs for insert to authenticated
  with check (
    created_by_profile_id = auth.uid()
    and public.is_approved_community_leader()
  );

drop policy if exists "Hub leaders update community hubs" on public.community_hubs;
create policy "Hub leaders update community hubs"
  on public.community_hubs for update to authenticated
  using (
    created_by_profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_hubs.id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  )
  with check (
    created_by_profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_hubs.id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  );

-- ---------------------------------------------------------------------------
-- Link Groups (communities) to hubs
-- ---------------------------------------------------------------------------
alter table public.communities
  add column if not exists hub_id uuid references public.community_hubs(id) on delete set null;

create index if not exists communities_hub_id_idx
  on public.communities (hub_id)
  where hub_id is not null;

create table if not exists public.community_group_link_requests (
  id uuid primary key default gen_random_uuid(),
  hub_id uuid not null references public.community_hubs(id) on delete cascade,
  community_id uuid not null references public.communities(id) on delete cascade,
  requested_by_profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  unique (hub_id, community_id)
);

create index if not exists community_group_link_requests_status_idx
  on public.community_group_link_requests (status, created_at desc);

alter table public.community_group_link_requests enable row level security;

drop policy if exists "Users read relevant group link requests" on public.community_group_link_requests;
create policy "Users read relevant group link requests"
  on public.community_group_link_requests for select to authenticated
  using (
    requested_by_profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.communities c
      where c.id = community_id
        and c.creator_id = auth.uid()
    )
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_group_link_requests.hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
    )
  );

drop policy if exists "Group leaders request hub links" on public.community_group_link_requests;
create policy "Group leaders request hub links"
  on public.community_group_link_requests for insert to authenticated
  with check (
    requested_by_profile_id = auth.uid()
    and exists (
      select 1 from public.communities c
      where c.id = community_id
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
  );

drop policy if exists "Hub leaders review group link requests" on public.community_group_link_requests;
create policy "Hub leaders review group link requests"
  on public.community_group_link_requests for update to authenticated
  using (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_group_link_requests.hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
    or (
      requested_by_profile_id = auth.uid()
      and status = 'pending'
    )
  )
  with check (true);

-- ---------------------------------------------------------------------------
-- Tighten Group membership insert for private groups (pending approval)
-- ---------------------------------------------------------------------------
drop policy if exists "Users join communities" on public.community_members;
create policy "Users join communities"
  on public.community_members for insert to authenticated
  with check (
    profile_id = auth.uid()
    and (
      (
        status = 'active'
        and exists (
          select 1 from public.communities c
          where c.id = community_id
            and c.privacy_type = 'public'
        )
      )
      or (
        status = 'pending'
        and exists (
          select 1 from public.communities c
          where c.id = community_id
            and c.privacy_type in ('private', 'hidden')
        )
      )
      or (
        status = 'active'
        and role in ('owner', 'admin')
        and exists (
          select 1 from public.communities c
          where c.id = community_id
            and c.creator_id = auth.uid()
        )
      )
    )
  );

drop policy if exists "Group leaders manage memberships" on public.community_members;
create policy "Group leaders manage memberships"
  on public.community_members for update to authenticated
  using (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.communities c
      where c.id = community_members.community_id
        and c.creator_id = auth.uid()
    )
    or exists (
      select 1 from public.community_members m
      where m.community_id = community_members.community_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
        and m.role in ('owner', 'admin', 'moderator')
    )
  )
  with check (true);

-- ---------------------------------------------------------------------------
-- Protect private Group posts from public reads
-- ---------------------------------------------------------------------------
drop policy if exists "Members read community-scoped posts" on public.community_news_posts;
create policy "Members read community-scoped posts"
  on public.community_news_posts for select to authenticated
  using (
    community_id is not null
    and (
      author_id = auth.uid()
      or public.is_firstvue_admin()
      or exists (
        select 1 from public.communities c
        where c.id = community_news_posts.community_id
          and (
            c.privacy_type = 'public'
            or c.creator_id = auth.uid()
            or exists (
              select 1 from public.community_members m
              where m.community_id = c.id
                and m.profile_id = auth.uid()
                and m.status = 'active'
            )
          )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Admin review helpers
-- ---------------------------------------------------------------------------
create or replace function public.review_community_leader_request(
  p_request_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
begin
  if not public.is_firstvue_admin() then
    raise exception 'Only FirstVue admins can review community leader requests';
  end if;

  select profile_id into v_profile_id
  from public.community_leader_requests
  where id = p_request_id
  for update;

  if v_profile_id is null then
    raise exception 'Request not found';
  end if;

  update public.community_leader_requests
  set
    status = case when p_approve then 'approved' else 'declined' end,
    reviewed_at = now(),
    reviewed_by = auth.uid()
  where id = p_request_id;

  if p_approve then
    insert into public.community_leaders (profile_id, approved_at, approved_by, status)
    values (v_profile_id, now(), auth.uid(), 'approved')
    on conflict (profile_id) do update
      set approved_at = excluded.approved_at,
          approved_by = excluded.approved_by,
          status = 'approved';
  end if;
end;
$$;

revoke all on function public.review_community_leader_request(uuid, boolean) from public;
grant execute on function public.review_community_leader_request(uuid, boolean) to authenticated;

create or replace function public.review_community_group_link_request(
  p_request_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hub_id uuid;
  v_community_id uuid;
begin
  select hub_id, community_id into v_hub_id, v_community_id
  from public.community_group_link_requests
  where id = p_request_id
  for update;

  if v_hub_id is null then
    raise exception 'Link request not found';
  end if;

  if not (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = v_hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  ) then
    raise exception 'Not authorized to review this link request';
  end if;

  update public.community_group_link_requests
  set
    status = case when p_approve then 'approved' else 'declined' end,
    reviewed_at = now(),
    reviewed_by = auth.uid()
  where id = p_request_id;

  if p_approve then
    update public.communities
    set hub_id = v_hub_id,
        updated_at = now()
    where id = v_community_id;
  end if;
end;
$$;

revoke all on function public.review_community_group_link_request(uuid, boolean) from public;
grant execute on function public.review_community_group_link_request(uuid, boolean) to authenticated;
