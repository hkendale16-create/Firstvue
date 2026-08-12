-- Follower/following list RPCs + profile read policy for social lists
-- Safe to re-run.

drop policy if exists "Authenticated read member profile summaries" on public.profiles;
create policy "Authenticated read member profile summaries"
  on public.profiles for select to authenticated
  using (display_name is not null or id = auth.uid());

create or replace function public.list_profile_followers(
  p_profile_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  display_name text,
  username citext
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.display_name, p.username
  from public.profile_follows pf
  join public.profiles p on p.id = pf.follower_id
  where pf.following_id = p_profile_id
  order by pf.created_at desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

create or replace function public.list_profile_following(
  p_profile_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  display_name text,
  username citext
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.display_name, p.username
  from public.profile_follows pf
  join public.profiles p on p.id = pf.following_id
  where pf.follower_id = p_profile_id
  order by pf.created_at desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.list_profile_followers(uuid, integer, integer) from public;
revoke all on function public.list_profile_following(uuid, integer, integer) from public;
grant execute on function public.list_profile_followers(uuid, integer, integer) to authenticated;
grant execute on function public.list_profile_following(uuid, integer, integer) to authenticated;
