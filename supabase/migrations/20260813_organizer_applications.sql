-- Organizer verification applications

create table if not exists public.community_organizer_applications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null,
  organization_name text,
  reason text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.community_organizer_applications enable row level security;

drop policy if exists "Users create organizer applications" on public.community_organizer_applications;
create policy "Users create organizer applications"
  on public.community_organizer_applications for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users read own organizer applications" on public.community_organizer_applications;
create policy "Users read own organizer applications"
  on public.community_organizer_applications for select to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Admins manage organizer applications" on public.community_organizer_applications;
create policy "Admins manage organizer applications"
  on public.community_organizer_applications for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

create index if not exists community_organizer_applications_status_idx
  on public.community_organizer_applications (status, created_at desc);
