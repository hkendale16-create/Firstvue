-- Flexible services list for FirstVue business profiles.
-- Run once in Supabase Dashboard > SQL Editor.

alter table public.businesses
  add column if not exists services text[] not null default '{}';
