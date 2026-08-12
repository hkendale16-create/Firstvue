-- Avatar, cover, and gallery roles for business/professional media + event cover photos.

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
