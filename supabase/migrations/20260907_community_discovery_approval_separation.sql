-- =============================================================================
-- FirstVue — community discovery + approval separation
--
-- Confirmed root causes (from codebase + prior live diagnosis):
-- 1) Community creation approval incorrectly grants global community_leaders.
-- 2) Flutter treats created_by / leader_user_id as management without an
--    active hub role / approved leadership relationship.
-- 3) Nearby group discovery over-filters by city/state with no empty fallback.
-- 4) Public hubs are authenticated-only (anon discovery empty).
-- 5) Group link approval updates communities.hub_id but not community_groups.
--
-- Additive / backward compatible. Does not recreate communities or wipe data.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Optional metro / handle columns for normalized discovery
-- ---------------------------------------------------------------------------
alter table public.community_hubs
  add column if not exists metro_area text,
  add column if not exists handle text,
  add column if not exists member_count integer not null default 0,
  add column if not exists show_managers_publicly boolean not null default false;

alter table public.communities
  add column if not exists metro_area text,
  add column if not exists handle text;

alter table public.user_preferences
  add column if not exists preferred_metro text;

create unique index if not exists community_hubs_handle_uidx
  on public.community_hubs (lower(handle))
  where handle is not null and length(trim(handle)) > 0;

create unique index if not exists communities_handle_uidx
  on public.communities (lower(handle))
  where handle is not null and length(trim(handle)) > 0;

create index if not exists community_hubs_metro_idx
  on public.community_hubs (lower(metro_area))
  where metro_area is not null;

create index if not exists community_hubs_active_public_idx
  on public.community_hubs (status, visibility, created_at desc)
  where status = 'active';

-- Backfill metro_area from city when missing (safe default).
update public.community_hubs
set metro_area = nullif(trim(city), '')
where metro_area is null
  and city is not null
  and length(trim(city)) > 0;

update public.communities
set metro_area = nullif(trim(city), '')
where metro_area is null
  and city is not null
  and length(trim(city)) > 0;

-- ---------------------------------------------------------------------------
-- B) Public read for approved public hubs (anon + authenticated)
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated read public community hubs" on public.community_hubs;
drop policy if exists "Public read approved community hubs" on public.community_hubs;
create policy "Public read approved community hubs"
  on public.community_hubs for select
  to anon, authenticated
  using (
    (
      status = 'active'
      and visibility = 'public'
    )
    or created_by_profile_id = auth.uid()
    or leader_user_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = community_hubs.id
        and r.profile_id = auth.uid()
        and r.status in ('active', 'pending')
    )
  );

-- Public groups remain readable when privacy_type = public (existing policies).
-- Ensure anon can also read public groups for discovery.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'communities'
      and policyname = 'Public read public groups'
  ) then
    create policy "Public read public groups"
      on public.communities for select
      to anon, authenticated
      using (
        privacy_type = 'public'
        or creator_id = auth.uid()
        or public.is_firstvue_admin()
        or exists (
          select 1 from public.community_members m
          where m.community_id = communities.id
            and m.profile_id = auth.uid()
            and m.status in ('active', 'pending')
        )
      );
  end if;
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- C) Helper: active hub management (not mere creator / pending)
-- ---------------------------------------------------------------------------
create or replace function public.is_active_hub_manager(p_hub_id uuid, p_profile_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_profile_id is not null
    and exists (
      select 1
      from public.community_hub_roles r
      where r.hub_id = p_hub_id
        and r.profile_id = p_profile_id
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    ),
    false
  );
$$;

revoke all on function public.is_active_hub_manager(uuid, uuid) from public;
grant execute on function public.is_active_hub_manager(uuid, uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- D) Community creation approval MUST NOT grant global leadership
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
  v_admin_count integer;
  v_visibility text;
  v_metro text;
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

  v_metro := nullif(trim(coalesce(v_req.city, '')), '');

  begin
    insert into public.community_hubs (
      name,
      description,
      category,
      city,
      state,
      postal_code,
      metro_area,
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
      v_metro,
      v_req.proposed_leader_user_id,
      null, -- leadership is a separate approval
      'active',
      v_req.id,
      v_visibility
    )
    returning id into v_hub_id;
  exception
    when unique_violation then
      raise exception 'A Community with this name or slug already exists';
  end;

  -- Proposed leader is pending for THIS community only. Does not grant
  -- global community_leaders or active management.
  insert into public.community_hub_roles (hub_id, profile_id, role, status)
  values (v_hub_id, v_req.proposed_leader_user_id, 'creator', 'pending')
  on conflict (hub_id, profile_id) do update
    set role = 'creator',
        status = case
          when community_hub_roles.status = 'active' then 'active'
          else 'pending'
        end;

  -- Ensure a separate pending leader request exists (do not auto-approve).
  if not exists (
    select 1 from public.community_leaders
    where profile_id = v_req.proposed_leader_user_id
      and status = 'approved'
  ) and not exists (
    select 1 from public.community_leader_requests
    where profile_id = v_req.proposed_leader_user_id
      and status = 'pending'
  ) then
    insert into public.community_leader_requests (
      profile_id,
      requested_city,
      requested_state,
      requested_location,
      reason,
      status
    ) values (
      v_req.proposed_leader_user_id,
      v_req.city,
      v_req.state,
      nullif(trim(coalesce(v_req.location_label, '')), ''),
      coalesce(
        nullif(trim(coalesce(v_req.reason, '')), ''),
        'Pending leadership for approved Community: ' || v_req.proposed_name
      ),
      'pending'
    );
  end if;

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
-- E) Leader approval activates pending hub management (no second community)
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
  v_status text;
begin
  if not public.is_firstvue_admin() then
    raise exception 'Only FirstVue admins can review community leader requests';
  end if;

  select profile_id, status into v_profile_id, v_status
  from public.community_leader_requests
  where id = p_request_id
  for update;

  if v_profile_id is null then
    raise exception 'Request not found';
  end if;

  if v_status <> 'pending' then
    raise exception 'Request is not pending (status=%)', v_status;
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

    -- Activate any pending hub creator/leader roles for this person.
    -- Never insert a new community_hubs row.
    update public.community_hub_roles
    set status = 'active'
    where profile_id = v_profile_id
      and status = 'pending'
      and role in ('creator', 'lead_leader', 'leader', 'admin');

    update public.community_hubs h
    set leader_user_id = v_profile_id
    where h.leader_user_id is null
      and exists (
        select 1 from public.community_hub_roles r
        where r.hub_id = h.id
          and r.profile_id = v_profile_id
          and r.status = 'active'
          and r.role in ('creator', 'lead_leader', 'leader', 'admin')
      );
  end if;
end;
$$;

revoke all on function public.review_community_leader_request(uuid, boolean) from public;
grant execute on function public.review_community_leader_request(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- F) Unify group-link approval with community_groups membership
-- ---------------------------------------------------------------------------
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
  v_status text;
begin
  select hub_id, community_id, status
    into v_hub_id, v_community_id, v_status
  from public.community_group_link_requests
  where id = p_request_id
  for update;

  if v_hub_id is null then
    raise exception 'Link request not found';
  end if;

  if v_status <> 'pending' then
    raise exception 'Link request is not pending (status=%)', v_status;
  end if;

  if not (
    public.is_firstvue_admin()
    or public.is_active_hub_manager(v_hub_id)
  ) then
    raise exception 'Not authorized to review this group link request';
  end if;

  update public.community_group_link_requests
  set
    status = case when p_approve then 'approved' else 'declined' end,
    reviewed_at = now(),
    reviewed_by = auth.uid()
  where id = p_request_id;

  if p_approve then
    update public.communities
    set hub_id = v_hub_id
    where id = v_community_id;

    insert into public.community_groups (
      community_id,
      group_id,
      status,
      can_post_to_community_feed,
      approved_by,
      approved_at
    ) values (
      v_hub_id,
      v_community_id,
      'approved',
      false,
      auth.uid(),
      now()
    )
    on conflict (community_id, group_id) do update
      set status = case
            when community_groups.status in ('approved', 'approved_for_feed')
              then community_groups.status
            else 'approved'
          end,
          approved_by = coalesce(community_groups.approved_by, auth.uid()),
          approved_at = coalesce(community_groups.approved_at, now());
  end if;
end;
$$;

revoke all on function public.review_community_group_link_request(uuid, boolean) from public;
grant execute on function public.review_community_group_link_request(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- G) Repair helpers for existing hubs that received leadership via community
--    creation approval. Keeps hub rows; demotes management only when the
--    profile is not an approved community_leader and not a FirstVue admin.
--    Safe to re-run. Production apply still requires explicit approval.
-- ---------------------------------------------------------------------------
update public.community_hub_roles r
set status = 'pending'
where r.status = 'active'
  and r.role in ('creator', 'lead_leader', 'leader')
  and not exists (
    select 1 from public.community_leaders cl
    where cl.profile_id = r.profile_id
      and cl.status = 'approved'
  )
  and not exists (
    select 1 from public.profiles p
    where p.id = r.profile_id
      and p.account_type = 'admin'
  );

update public.community_hubs h
set leader_user_id = null
where h.leader_user_id is not null
  and not exists (
    select 1 from public.community_leaders cl
    where cl.profile_id = h.leader_user_id
      and cl.status = 'approved'
  )
  and not exists (
    select 1 from public.profiles p
    where p.id = h.leader_user_id
      and p.account_type = 'admin'
  );

insert into public.community_leader_requests (
  profile_id,
  requested_city,
  requested_state,
  requested_location,
  reason,
  status
)
select distinct
  h.created_by_profile_id,
  h.city,
  h.state,
  nullif(trim(concat_ws(', ', h.city, h.state)), ''),
  'Pending leadership for approved Community: ' || h.name,
  'pending'
from public.community_hubs h
where h.status = 'active'
  and h.created_by_profile_id is not null
  and not exists (
    select 1 from public.community_leaders cl
    where cl.profile_id = h.created_by_profile_id
      and cl.status = 'approved'
  )
  and not exists (
    select 1 from public.community_leader_requests lr
    where lr.profile_id = h.created_by_profile_id
      and lr.status in ('pending', 'approved')
  )
  and not exists (
    select 1 from public.profiles p
    where p.id = h.created_by_profile_id
      and p.account_type = 'admin'
  );
