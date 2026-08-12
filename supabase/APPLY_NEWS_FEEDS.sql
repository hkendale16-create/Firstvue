-- Paste this entire file into Supabase SQL Editor and Run.

-- Dashboard: https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new

-- Source: migrations/20260831_news_feeds.sql

-- =============================================================================
-- FirstVue — News Feeds (Home Community + entity scopes)
-- Safe to re-run in the Supabase SQL Editor.
-- Does NOT drop or recreate community_news_posts; existing posts stay intact.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Columns the app selects / filters on
-- ---------------------------------------------------------------------------
alter table public.community_news_posts
  add column if not exists visibility text not null default 'public';

alter table public.community_news_posts
  drop constraint if exists community_news_posts_visibility_check;

alter table public.community_news_posts
  add constraint community_news_posts_visibility_check
  check (visibility in ('public', 'followers', 'community', 'private'));

alter table public.community_news_posts
  add column if not exists community_id uuid
    references public.communities(id) on delete set null;

alter table public.community_news_posts
  add column if not exists professional_profile_id uuid
    references public.professional_profiles(id) on delete set null;

alter table public.community_news_posts
  add column if not exists event_id uuid
    references public.community_events(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 2) Feed indexes (Home, Community, Groups, profiles, businesses, events)
-- ---------------------------------------------------------------------------
create index if not exists community_news_posts_created_idx
  on public.community_news_posts (created_at desc);

create index if not exists community_news_posts_status_created_idx
  on public.community_news_posts (status, created_at desc);

create index if not exists community_news_posts_community_idx
  on public.community_news_posts (community_id, created_at desc)
  where community_id is not null;

create index if not exists community_news_posts_author_idx
  on public.community_news_posts (author_id, created_at desc);

create index if not exists community_news_posts_business_idx
  on public.community_news_posts (business_id, created_at desc)
  where business_id is not null;

create index if not exists community_news_posts_professional_idx
  on public.community_news_posts (professional_profile_id, created_at desc)
  where professional_profile_id is not null;

create index if not exists community_news_posts_event_idx
  on public.community_news_posts (event_id, created_at desc)
  where event_id is not null;

create index if not exists community_news_posts_visibility_idx
  on public.community_news_posts (visibility, created_at desc)
  where status = 'approved';

-- ---------------------------------------------------------------------------
-- 3) RLS — read policies used by Home / Community / entity news feeds
-- ---------------------------------------------------------------------------
alter table public.community_news_posts enable row level security;

-- Authors always see their own posts (any status / visibility).
drop policy if exists "Authors read their news posts" on public.community_news_posts;
create policy "Authors read their news posts"
  on public.community_news_posts for select to authenticated
  using (author_id = auth.uid());

-- Public Home + Community feed posts.
drop policy if exists "Public reads approved news posts" on public.community_news_posts;
create policy "Public reads approved news posts"
  on public.community_news_posts for select
  using (
    status = 'approved'
    and coalesce(visibility, 'public') = 'public'
  );

-- Followers-only posts.
drop policy if exists "Followers read followers-only news posts" on public.community_news_posts;
create policy "Followers read followers-only news posts"
  on public.community_news_posts for select to authenticated
  using (
    status = 'approved'
    and coalesce(visibility, 'public') = 'followers'
    and (
      author_id = auth.uid()
      or exists (
        select 1
        from public.profile_follows pf
        where pf.follower_id = auth.uid()
          and pf.following_id = community_news_posts.author_id
      )
    )
  );

-- Community/Group-only posts (members of that community).
drop policy if exists "Members read community-only news posts" on public.community_news_posts;
create policy "Members read community-only news posts"
  on public.community_news_posts for select to authenticated
  using (
    status = 'approved'
    and visibility = 'community'
    and community_id is not null
    and (
      author_id = auth.uid()
      or exists (
        select 1
        from public.community_members cm
        where cm.community_id = community_news_posts.community_id
          and cm.profile_id = auth.uid()
          and cm.status = 'active'
      )
    )
  );

-- Private posts: author only (also covered by author policy; explicit for clarity).
drop policy if exists "Authors read private news posts" on public.community_news_posts;
create policy "Authors read private news posts"
  on public.community_news_posts for select to authenticated
  using (
    status = 'approved'
    and visibility = 'private'
    and author_id = auth.uid()
  );

-- Insert / delete (idempotent refresh of base write policies).
drop policy if exists "Authenticated users post news" on public.community_news_posts;
create policy "Authenticated users post news"
  on public.community_news_posts for insert to authenticated
  with check (author_id = auth.uid());

drop policy if exists "Authors delete their news posts" on public.community_news_posts;
create policy "Authors delete their news posts"
  on public.community_news_posts for delete to authenticated
  using (author_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4) Sparks — public read so feed cards can show counts
-- ---------------------------------------------------------------------------
alter table public.community_news_post_sparks enable row level security;

drop policy if exists "Public reads news spark counts" on public.community_news_post_sparks;
create policy "Public reads news spark counts"
  on public.community_news_post_sparks for select
  using (true);

drop policy if exists "Authenticated users spark news posts" on public.community_news_post_sparks;
create policy "Authenticated users spark news posts"
  on public.community_news_post_sparks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 5) Realtime for live Home / Community news feed inserts
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'community_news_posts'
  ) then
    alter publication supabase_realtime add table public.community_news_posts;
  end if;

  if to_regclass('public.feed_comments') is not null
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'feed_comments'
     ) then
    alter publication supabase_realtime add table public.feed_comments;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 6) Optional helper view — Community News Feed (posts with a community_id)
--    App can keep querying community_news_posts directly; this is for SQL /
--    dashboards / debugging.
-- ---------------------------------------------------------------------------
create or replace view public.community_news_feed_view
with (security_invoker = true)
as
select
  p.id,
  p.body,
  p.created_at,
  p.author_id,
  p.business_id,
  p.community_id,
  p.professional_profile_id,
  p.event_id,
  p.visibility,
  p.status,
  coalesce(pr.display_name, 'Member') as author_name,
  pr.username as author_username,
  -- Avatars live in profile_media (media_role = 'avatar'), not profiles.avatar_url
  pm.storage_path as author_avatar_path,
  c.name as community_name,
  (
    select count(*)::int
    from public.community_news_post_sparks s
    where s.post_id = p.id
  ) as spark_count
from public.community_news_posts p
left join public.profiles pr on pr.id = p.author_id
left join public.communities c on c.id = p.community_id
left join public.profile_media pm
  on pm.profile_id = p.author_id
 and pm.media_role = 'avatar'
where p.status = 'approved'
  and p.community_id is not null
order by p.created_at desc;

grant select on public.community_news_feed_view to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7) Verify
-- ---------------------------------------------------------------------------
-- select column_name
-- from information_schema.columns
-- where table_schema = 'public'
--   and table_name = 'community_news_posts'
--   and column_name in (
--     'visibility', 'community_id', 'professional_profile_id', 'event_id'
--   );
--
-- select indexname
-- from pg_indexes
-- where schemaname = 'public'
--   and tablename = 'community_news_posts'
--   and indexname like 'community_news_posts_%';
--
-- select * from public.community_news_feed_view limit 20;
