-- FIRSTVUE individual professional profiles.
-- Barbers, stylists, and beauty professionals are people, not business locations.
-- Run once in Supabase Dashboard > SQL Editor.

create table if not exists public.professional_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 120),
  professional_type text not null
    check (professional_type in ('barber', 'stylist', 'beauty_professional')),
  bio text not null default '' check (char_length(bio) <= 2000),
  city text not null default '',
  state text not null default '',
  postal_code text not null default '',
  services text[] not null default '{}',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists professional_profiles_discovery_idx
  on public.professional_profiles (professional_type, status, created_at desc);

alter table public.professional_profiles enable row level security;

drop policy if exists "Public reads approved professional profiles" on public.professional_profiles;
drop policy if exists "Professionals create their own profile" on public.professional_profiles;
drop policy if exists "Professionals read their own profile" on public.professional_profiles;
drop policy if exists "Professionals update their pending profile" on public.professional_profiles;
drop policy if exists "FirstVue admins manage professional profiles" on public.professional_profiles;

create policy "Public reads approved professional profiles"
  on public.professional_profiles for select
  using (status = 'approved');

create policy "Professionals create their own profile"
  on public.professional_profiles for insert to authenticated
  with check (
    profile_id = auth.uid()
    and status = 'pending'
  );

create policy "Professionals read their own profile"
  on public.professional_profiles for select to authenticated
  using (profile_id = auth.uid());

create policy "Professionals update their pending profile"
  on public.professional_profiles for update to authenticated
  using (profile_id = auth.uid())
  with check (
    profile_id = auth.uid()
    and status in ('pending', 'rejected')
  );

create policy "FirstVue admins manage professional profiles"
  on public.professional_profiles for all to authenticated
  using (
    exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  );

-- Users who submit a professional profile are identified as professionals.
-- This update is intentionally limited to the authenticated user's own row by
-- the existing profiles RLS policy.
