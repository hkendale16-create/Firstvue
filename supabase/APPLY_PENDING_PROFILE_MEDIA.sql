-- FIRSTVUE: Apply profile media + entity news feed migrations in one session.
-- Run in Supabase Dashboard → SQL Editor → New query.
--
-- Combines:
--   1. supabase/migrations/20260825_entity_profile_media_roles.sql
--   2. supabase/migrations/20260826_profile_entity_news_feeds.sql
--
-- Prerequisites: business_media, professional_media, community_events, and
-- community_news_posts tables must already exist (earlier migrations applied).
--
-- IMPORTANT: Copy the ENTIRE file below (including lines that start with --).
-- Do NOT paste description lines without the leading "--" — PostgreSQL treats
-- those as invalid SQL and will error with "syntax error at or near ...".

-- =============================================================================
-- 1. entity_profile_media_roles (20260825)
-- Avatar, cover, and gallery roles for business/professional media + event cover photos.
-- =============================================================================

alter table public.business_media
  add column if not exists media_role text not null default 'gallery';

alter table public.business_media
  drop constraint if exists business_media_media_role_check;

alter table public.business_media
  add constraint business_media_media_role_check
  check (media_role in ('gallery', 'avatar', 'cover'));

create unique index if not exists business_media_one_avatar_idx
  on public.business_media (business_id)
  where media_role = 'avatar';

create unique index if not exists business_media_one_cover_idx
  on public.business_media (business_id)
  where media_role = 'cover';

alter table public.professional_media
  add column if not exists media_role text not null default 'gallery';

alter table public.professional_media
  drop constraint if exists professional_media_media_role_check;

alter table public.professional_media
  add constraint professional_media_media_role_check
  check (media_role in ('gallery', 'avatar', 'cover'));

create unique index if not exists professional_media_one_avatar_idx
  on public.professional_media (professional_profile_id)
  where media_role = 'avatar';

create unique index if not exists professional_media_one_cover_idx
  on public.professional_media (professional_profile_id)
  where media_role = 'cover';

-- Event cover image (single hero photo per event listing)
alter table public.community_events
  add column if not exists cover_storage_path text,
  add column if not exists cover_storage_provider text default 'supabase';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'event-media',
  'event-media',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists "Organizers upload event media" on storage.objects;
create policy "Organizers upload event media"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'event-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Organizers delete event media" on storage.objects;
create policy "Organizers delete event media"
  on storage.objects for delete to authenticated
  using (bucket_id = 'event-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Authenticated users view event media" on storage.objects;
create policy "Authenticated users view event media"
  on storage.objects for select to authenticated
  using (bucket_id = 'event-media');

-- =============================================================================
-- 2. profile_entity_news_feeds (20260826)
-- Posts scoped to professional profiles and community events.
-- =============================================================================

alter table public.community_news_posts
  add column if not exists professional_profile_id uuid
    references public.professional_profiles(id) on delete set null;

alter table public.community_news_posts
  add column if not exists event_id uuid
    references public.community_events(id) on delete set null;

create index if not exists community_news_posts_business_idx
  on public.community_news_posts (business_id, created_at desc)
  where business_id is not null;

create index if not exists community_news_posts_professional_idx
  on public.community_news_posts (professional_profile_id, created_at desc)
  where professional_profile_id is not null;

create index if not exists community_news_posts_event_idx
  on public.community_news_posts (event_id, created_at desc)
  where event_id is not null;
