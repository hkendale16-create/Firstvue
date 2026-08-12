-- Profile avatar/cover roles and news post media storage bucket tracking.

alter table public.profile_media
  add column if not exists media_role text not null default 'gallery'
  check (media_role in ('gallery', 'avatar', 'cover'));

create unique index if not exists profile_media_one_avatar_per_profile
  on public.profile_media (profile_id)
  where media_role = 'avatar';

create unique index if not exists profile_media_one_cover_per_profile
  on public.profile_media (profile_id)
  where media_role = 'cover';

alter table public.community_news_post_media
  add column if not exists storage_bucket text not null default 'community-news-media';
