-- Paste entire file into Supabase SQL Editor and Run.
-- Owner/leader permanent deletion for Groups and Communities (safe to re-run).
-- Mirrors supabase/migrations/20261013_delete_owned_groups_communities.sql

create or replace function public.delete_owned_group(p_group_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_creator uuid;
  v_name text;
  v_is_owner boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  select creator_id, name into v_creator, v_name
  from public.communities
  where id = p_group_id
  for update;

  if not found then
    raise exception 'Group not found'
      using errcode = 'P0002';
  end if;

  select exists (
    select 1
    from public.community_members m
    where m.community_id = p_group_id
      and m.profile_id = auth.uid()
      and m.status = 'active'
      and m.role = 'owner'
  ) into v_is_owner;

  if coalesce(v_creator, '00000000-0000-0000-0000-000000000000'::uuid) <> auth.uid()
     and not v_is_owner
     and not public.is_firstvue_admin() then
    raise exception 'Only the group owner or creator can permanently delete this group'
      using errcode = '42501';
  end if;

  delete from public.community_news_posts
  where community_id = p_group_id;

  delete from public.communities where id = p_group_id;
end;
$$;

comment on function public.delete_owned_group(uuid) is
  'Owner/creator-only permanent Group deletion. Cascades members/follows/tags/links. Removes group news posts.';

revoke all on function public.delete_owned_group(uuid) from public;
grant execute on function public.delete_owned_group(uuid) to authenticated;

create or replace function public.delete_owned_community_hub(p_hub_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_creator uuid;
  v_leader uuid;
  v_name text;
  v_is_leader boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  select created_by_profile_id, leader_user_id, name
    into v_creator, v_leader, v_name
  from public.community_hubs
  where id = p_hub_id
  for update;

  if not found then
    raise exception 'Community not found'
      using errcode = 'P0002';
  end if;

  select exists (
    select 1
    from public.community_hub_roles r
    where r.hub_id = p_hub_id
      and r.profile_id = auth.uid()
      and r.status = 'active'
      and r.role in ('creator', 'lead_leader', 'leader')
  ) into v_is_leader;

  if v_creator <> auth.uid()
     and coalesce(v_leader, '00000000-0000-0000-0000-000000000000'::uuid) <> auth.uid()
     and not v_is_leader
     and not public.is_firstvue_admin() then
    raise exception 'Only the community creator or leader can permanently delete this community'
      using errcode = '42501';
  end if;

  update public.community_creation_requests
  set created_community_id = null
  where created_community_id = p_hub_id;

  delete from public.community_hubs where id = p_hub_id;
end;
$$;

comment on function public.delete_owned_community_hub(uuid) is
  'Creator/leader-only permanent Community (hub) deletion. Cascades roles/follows/editors/links. Groups remain and are unlinked.';

revoke all on function public.delete_owned_community_hub(uuid) from public;
grant execute on function public.delete_owned_community_hub(uuid) to authenticated;
