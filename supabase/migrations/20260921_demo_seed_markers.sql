-- Demo pack markers + external media URLs for seed content.
-- Safe to re-run. Full seed data lives in supabase/APPLY_DEMO_SEED.sql.

alter table public.profiles
  add column if not exists is_demo boolean not null default false;

alter table public.businesses
  add column if not exists is_demo boolean not null default false;

alter table public.community_events
  add column if not exists is_demo boolean not null default false;

alter table public.community_news_posts
  add column if not exists is_demo boolean not null default false;

create index if not exists profiles_is_demo_idx
  on public.profiles (id)
  where is_demo = true;

-- Allow https demo assets without uploading to Storage.
do $$
begin
  alter table public.profile_media
    drop constraint if exists profile_media_storage_provider_check;
  alter table public.profile_media
    add constraint profile_media_storage_provider_check
    check (storage_provider in ('supabase', 's3', 'external'));

  alter table public.community_news_post_media
    drop constraint if exists community_news_post_media_storage_provider_check;
  alter table public.community_news_post_media
    add constraint community_news_post_media_storage_provider_check
    check (storage_provider in ('supabase', 's3', 'external'));

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'business_media'
      and column_name = 'storage_provider'
  ) then
    alter table public.business_media
      drop constraint if exists business_media_storage_provider_check;
    alter table public.business_media
      add constraint business_media_storage_provider_check
      check (storage_provider in ('supabase', 's3', 'external'));
  else
    alter table public.business_media
      add column storage_provider text not null default 'supabase';
    alter table public.business_media
      add constraint business_media_storage_provider_check
      check (storage_provider in ('supabase', 's3', 'external'));
  end if;

  alter table public.business_media
    add column if not exists media_type text not null default 'image';
  alter table public.business_media
    add column if not exists caption text;
  alter table public.business_media
    add column if not exists thumbnail_path text;
  alter table public.business_media
    add column if not exists featured_for_trending boolean not null default false;
end $$;
