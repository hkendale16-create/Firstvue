-- FirstVue: Community owner/admin/leader posting + role alignment
-- Paste into Supabase SQL Editor for project sdssshegqdwobjelxzkp.
-- Safe to re-run.

-- ---------------------------------------------------------------------------
-- 1) Leaders include hub admins (Flutter isActiveManager already does).
-- ---------------------------------------------------------------------------
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
      and r.role in ('creator', 'lead_leader', 'leader', 'admin')
  )
  or public.is_firstvue_admin();
$$;

revoke all on function public.is_community_leader(uuid) from public;
grant execute on function public.is_community_leader(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Approving Community creation activates the owner as creator + leader.
--    Owners must not wait for a separate self-approval.
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
  v_owner uuid;
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
  v_owner := coalesce(v_req.proposed_leader_user_id, v_req.requesting_user_id);

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
      v_owner,
      v_owner,
      'active',
      v_req.id,
      v_visibility
    )
    returning id into v_hub_id;
  exception
    when unique_violation then
      raise exception 'A Community with this name or slug already exists';
  end;

  -- Owner is immediately active creator (highest hub privilege).
  insert into public.community_hub_roles (hub_id, profile_id, role, status)
  values (v_hub_id, v_owner, 'creator', 'active')
  on conflict (hub_id, profile_id) do update
    set role = 'creator',
        status = 'active';

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
-- 3) Repair existing hubs: owners stuck as pending creators.
-- ---------------------------------------------------------------------------
update public.community_hub_roles r
set status = 'active'
from public.community_hubs h
where r.hub_id = h.id
  and r.profile_id = h.created_by_profile_id
  and r.role = 'creator'
  and r.status = 'pending';

update public.community_hubs h
set leader_user_id = h.created_by_profile_id
where h.leader_user_id is null
  and h.created_by_profile_id is not null
  and h.status = 'active';

-- ---------------------------------------------------------------------------
-- 4) Ensure a feed-enabled Group so hub managers can post with CreatePostScreen.
-- ---------------------------------------------------------------------------
create or replace function public.ensure_hub_newsfeed_group(p_hub_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_group_id uuid;
  v_hub_name text;
  v_link_id uuid;
begin
  if v_me is null then
    raise exception 'Authentication required';
  end if;

  if not (
    public.is_active_hub_manager(p_hub_id, v_me)
    or public.community_editor_has_permission(p_hub_id, 'manage_newsfeed')
  ) then
    raise exception 'Not authorized to post to this Community newsfeed';
  end if;

  select name into v_hub_name
  from public.community_hubs
  where id = p_hub_id and status = 'active';

  if v_hub_name is null then
    raise exception 'Community not found';
  end if;

  -- Prefer an existing feed-enabled linked group where the caller can post.
  select cg.group_id into v_group_id
  from public.community_groups cg
  where cg.community_id = p_hub_id
    and cg.can_post_to_community_feed = true
    and cg.status in ('approved', 'approved_for_feed')
    and cg.removed_at is null
    and (
      exists (
        select 1 from public.community_members cm
        where cm.community_id = cg.group_id
          and cm.profile_id = v_me
          and cm.status = 'active'
      )
      or exists (
        select 1 from public.communities c
        where c.id = cg.group_id and c.creator_id = v_me
      )
    )
  order by cg.created_at asc
  limit 1;

  if v_group_id is not null then
    return v_group_id;
  end if;

  -- Reuse a dedicated newsfeed group for this hub if present.
  select c.id into v_group_id
  from public.communities c
  where c.hub_id = p_hub_id
    and c.name = left(v_hub_name || ' Newsfeed', 80)
  limit 1;

  if v_group_id is null then
    insert into public.communities (
      name,
      description,
      creator_id,
      hub_id,
      privacy_type,
      posting_permission,
      member_count,
      follower_count
    ) values (
      left(v_hub_name || ' Newsfeed', 80),
      'Official Community Newsfeed for ' || v_hub_name,
      v_me,
      p_hub_id,
      'public',
      'members',
      1,
      0
    )
    returning id into v_group_id;
  end if;

  insert into public.community_members (community_id, profile_id, role, status)
  values (v_group_id, v_me, 'owner', 'active')
  on conflict (community_id, profile_id) do update
    set status = 'active',
        role = case
          when community_members.role in ('owner', 'admin') then community_members.role
          else 'owner'
        end;

  insert into public.community_groups (
    community_id,
    group_id,
    status,
    can_post_to_community_feed,
    approved_by,
    approved_at,
    posting_approved_by,
    posting_approved_at
  ) values (
    p_hub_id,
    v_group_id,
    'approved_for_feed',
    true,
    v_me,
    now(),
    v_me,
    now()
  )
  on conflict (community_id, group_id) do update
    set status = 'approved_for_feed',
        can_post_to_community_feed = true,
        removed_at = null,
        posting_approved_by = coalesce(community_groups.posting_approved_by, v_me),
        posting_approved_at = coalesce(community_groups.posting_approved_at, now())
  returning id into v_link_id;

  return v_group_id;
end;
$$;

revoke all on function public.ensure_hub_newsfeed_group(uuid) from public;
grant execute on function public.ensure_hub_newsfeed_group(uuid) to authenticated;

comment on function public.ensure_hub_newsfeed_group(uuid) is
  'Returns a Group id linked to the hub with feed posting enabled so managers can use CreatePostScreen.';
