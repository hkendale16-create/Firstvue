-- FIRSTVUE professional availability and private portfolio image storage.
-- Run after 20260811_professional_profiles.sql.

alter table public.professional_profiles
  add column if not exists accepts_new_clients boolean not null default true,
  add column if not exists availability_note text not null default '',
  add column if not exists booking_url text not null default '';

alter table public.professional_profiles
  drop constraint if exists professional_profiles_availability_note_length;
alter table public.professional_profiles
  add constraint professional_profiles_availability_note_length
  check (char_length(availability_note) <= 500);

alter table public.professional_profiles
  drop constraint if exists professional_profiles_booking_url_length;
alter table public.professional_profiles
  add constraint professional_profiles_booking_url_length
  check (char_length(booking_url) <= 500);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'professional-media',
  'professional-media',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create table if not exists public.professional_media (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  storage_path text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.professional_media enable row level security;

drop policy if exists "Professionals manage their portfolio records" on public.professional_media;
drop policy if exists "Authenticated users view approved professional portfolio records" on public.professional_media;
drop policy if exists "Professionals upload portfolio media" on storage.objects;
drop policy if exists "Professionals delete portfolio media" on storage.objects;
drop policy if exists "Authenticated users view approved professional portfolio files" on storage.objects;

create policy "Professionals manage their portfolio records"
  on public.professional_media for all to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  );

create policy "Authenticated users view approved professional portfolio records"
  on public.professional_media for select to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create policy "Professionals upload portfolio media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'professional-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Professionals delete portfolio media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'professional-media'
    and owner_id = auth.uid()::text
  );

create policy "Authenticated users view approved professional portfolio files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'professional-media'
    and exists (
      select 1
      from public.professional_media media
      join public.professional_profiles professional
        on professional.id = media.professional_profile_id
      where media.storage_path = name
        and professional.status = 'approved'
    )
  );
