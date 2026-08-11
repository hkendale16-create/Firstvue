-- Private photo storage and media records for FirstVue business profiles.
-- Run once in Supabase Dashboard > SQL Editor.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('business-media', 'business-media', false, 52428800, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create table if not exists public.business_media (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  storage_path text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.business_media enable row level security;

drop policy if exists "Owners manage their business media records" on public.business_media;
drop policy if exists "Authenticated users view approved business media records" on public.business_media;
drop policy if exists "Owners upload business media" on storage.objects;
drop policy if exists "Owners delete business media" on storage.objects;
drop policy if exists "Authenticated users view approved business media files" on storage.objects;

create policy "Owners manage their business media records" on public.business_media for all to authenticated
using (exists (select 1 from public.businesses business where business.id = business_id and business.created_by = auth.uid()))
with check (exists (select 1 from public.businesses business where business.id = business_id and business.created_by = auth.uid()));

create policy "Authenticated users view approved business media records" on public.business_media for select to authenticated
using (exists (select 1 from public.businesses business where business.id = business_id and business.status = 'approved'));

create policy "Owners upload business media" on storage.objects for insert to authenticated
with check (bucket_id = 'business-media' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Owners delete business media" on storage.objects for delete to authenticated
using (bucket_id = 'business-media' and owner_id = auth.uid()::text);

create policy "Authenticated users view approved business media files" on storage.objects for select to authenticated
using (bucket_id = 'business-media' and exists (
  select 1 from public.business_media media join public.businesses business on business.id = media.business_id
  where media.storage_path = name and business.status = 'approved'
));
