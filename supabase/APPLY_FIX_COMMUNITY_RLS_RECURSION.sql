-- =============================================================================
-- FIX: signed-in infinite RLS recursion (42P17) on community_members
--
-- Symptom:
--   Authenticated SELECT on community_news_posts / communities returns 500:
--   "infinite recursion detected in policy for relation \"community_members\""
--   Anon reads still work. Explore People may show cards but feeds/posts fail.
--   Authenticated storage createSignedUrl can also fail while anon signing works.
--
-- Cycle:
--   communities SELECT exists(community_members)
--   community_members SELECT exists(communities)
--
-- Fix: SECURITY DEFINER helpers + rewrite policies to call helpers only.
-- Safe to re-run.
-- Paste into Supabase SQL Editor for project sdssshegqdwobjelxzkp.
-- =============================================================================

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

comment on function public.is_community_member(uuid, uuid) is
  'Non-recursive community membership check. SECURITY DEFINER bypasses community_members RLS.';

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

comment on function public.is_public_community(uuid) is
  'Non-recursive public-community check. SECURITY DEFINER bypasses communities RLS.';

revoke all on function public.is_community_member(uuid, uuid) from public;
grant execute on function public.is_community_member(uuid, uuid) to anon, authenticated;

revoke all on function public.is_public_community(uuid) from public;
grant execute on function public.is_public_community(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- community_members — never SELECT communities under RLS here
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- communities — never SELECT community_members under RLS here
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- community_news_posts — use helper instead of raw members subquery
-- ---------------------------------------------------------------------------
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
