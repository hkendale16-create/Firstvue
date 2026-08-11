-- Persistent submissions for new/unlisted businesses.
-- Run once in Supabase Dashboard > SQL Editor.

alter table public.businesses add column if not exists business_type text;

create table if not exists public.business_verification_submissions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  submitter_id uuid not null references public.profiles(id) on delete cascade,
  contact_name text not null,
  contact_email text not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.business_verification_submissions enable row level security;

drop policy if exists "Users create their own businesses" on public.businesses;
drop policy if exists "Users read their own businesses" on public.businesses;
drop policy if exists "Users create their own business submissions" on public.business_verification_submissions;
drop policy if exists "Users read their own business submissions" on public.business_verification_submissions;

create policy "Users create their own businesses"
  on public.businesses for insert to authenticated
  with check (created_by = auth.uid());

create policy "Users read their own businesses"
  on public.businesses for select to authenticated
  using (created_by = auth.uid());

create policy "Users create their own business submissions"
  on public.business_verification_submissions for insert to authenticated
  with check (submitter_id = auth.uid());

create policy "Users read their own business submissions"
  on public.business_verification_submissions for select to authenticated
  using (submitter_id = auth.uid());
