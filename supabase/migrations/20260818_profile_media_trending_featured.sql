-- Profile media for all users, video on professional portfolios, trending cover picks.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-media',
  'profile-media',
  false,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/bmp',
    'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
    'video/x-matroska', 'video/x-m4v'
  ]
)
on conflict (id) do update
set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.profile_media (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3')),
  media_type text not null default 'image'
    check (media_type in ('image', 'video')),
  featured_for_trending boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profile_media enable row level security;

drop policy if exists "Users manage their profile media" on public.profile_media;
create policy "Users manage their profile media"
  on public.profile_media for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Authenticated users read profile media" on public.profile_media;
create policy "Authenticated users read profile media"
  on public.profile_media for select to authenticated
  using (true);

alter table public.business_media
  add column if not exists featured_for_trending boolean not null default false;

alter table public.professional_media
  add column if not exists storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3'));

alter table public.professional_media
  add column if not exists media_type text not null default 'image'
    check (media_type in ('image', 'video'));

alter table public.professional_media
  add column if not exists featured_for_trending boolean not null default false;

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/bmp',
  'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
  'video/x-matroska', 'video/x-m4v'
]
where id = 'professional-media';

drop policy if exists "Professionals view their portfolio files" on storage.objects;
create policy "Professionals view their portfolio files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'professional-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.professional_media media
        join public.professional_profiles professional
          on professional.id = media.professional_profile_id
        where media.storage_path = name
          and professional.profile_id = auth.uid()
      )
    )
  );

drop policy if exists "Users upload profile media" on storage.objects;
create policy "Users upload profile media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users delete profile media files" on storage.objects;
create policy "Users delete profile media files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-media'
    and owner_id = auth.uid()::text
  );

drop policy if exists "Authenticated users read profile media files" on storage.objects;
create policy "Authenticated users read profile media files"
  on storage.objects for select to authenticated
  using (bucket_id = 'profile-media');

create index if not exists profile_media_profile_idx
  on public.profile_media (profile_id, sort_order);

create index if not exists business_media_trending_idx
  on public.business_media (business_id, featured_for_trending)
  where featured_for_trending = true;

create index if not exists professional_media_trending_idx
  on public.professional_media (professional_profile_id, featured_for_trending)
  where featured_for_trending = true;
