-- Same as supabase/APPLY_FIX_COMMUNITY_RLS_RECURSION.sql
-- Breaks signed-in 42P17 recursion between communities and community_members.

create or replace function public.is_community_member(
  p_community_id uuid,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_profile_id is not null
    and p_community_id is not null
    and exists (
      select 1
      from public.community_members m
      where m.community_id = p_community_id
        and m.profile_id = p_profile_id
        and coalesce(m.status, 'active') in ('active', 'pending')
    ),
    false
  );
$$;

create or replace function public.is_public_community(p_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_community_id is not null
    and exists (
      select 1
      from public.communities c
      where c.id = p_community_id
        and coalesce(c.privacy_type, 'public') = 'public'
    ),
    false
  );
$$;

revoke all on function public.is_community_member(uuid, uuid) from public;
grant execute on function public.is_community_member(uuid, uuid) to anon, authenticated;

revoke all on function public.is_public_community(uuid) from public;
grant execute on function public.is_public_community(uuid) to anon, authenticated;

drop policy if exists "Authenticated read community members" on public.community_members;
drop policy if exists "Members read community members" on public.community_members;
drop policy if exists "Public read community members" on public.community_members;

create policy "Members read community members"
  on public.community_members for select to authenticated
  using (
    profile_id = auth.uid()
    or public.is_firstvue_admin()
    or public.is_community_member(community_id, auth.uid())
    or public.is_public_community(community_id)
  );

drop policy if exists "Public read public groups" on public.communities;
drop policy if exists "Authenticated read communities" on public.communities;
drop policy if exists "Users read communities" on public.communities;

create policy "Public read public groups"
  on public.communities for select
  to anon, authenticated
  using (
    coalesce(privacy_type, 'public') = 'public'
    or creator_id = auth.uid()
    or public.is_firstvue_admin()
    or public.is_community_member(id, auth.uid())
  );

drop policy if exists "Members read community-only news posts" on public.community_news_posts;
drop policy if exists "Members read community-scoped posts" on public.community_news_posts;

create policy "Members read community-only news posts"
  on public.community_news_posts for select to authenticated
  using (
    status = 'approved'
    and visibility = 'community'
    and community_id is not null
    and (
      author_id = auth.uid()
      or public.is_community_member(community_id, auth.uid())
    )
  );
