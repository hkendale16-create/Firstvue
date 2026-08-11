-- Phase 3B: Track whether media lives in Supabase Storage or AWS S3.

alter table public.business_media
  add column if not exists storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3'));

alter table public.rental_media
  add column if not exists storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3'));

alter table public.professional_media
  add column if not exists storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3'));
