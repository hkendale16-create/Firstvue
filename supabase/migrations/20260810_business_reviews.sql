-- FirstVue customer reviews with moderation-ready status.
-- Run once in Supabase Dashboard > SQL Editor.

create table if not exists public.business_reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text not null check (char_length(body) between 1 and 2000),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'reported')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, reviewer_id)
);

alter table public.business_reviews enable row level security;

create policy "Authenticated users read approved reviews"
  on public.business_reviews for select to authenticated using (status = 'approved');
create policy "Users read their own reviews"
  on public.business_reviews for select to authenticated using (reviewer_id = auth.uid());
create policy "Users create their own reviews"
  on public.business_reviews for insert to authenticated with check (reviewer_id = auth.uid());
create policy "Users update their own pending reviews"
  on public.business_reviews for update to authenticated
  using (reviewer_id = auth.uid() and status = 'pending')
  with check (reviewer_id = auth.uid() and status = 'pending');
create policy "FirstVue admins manage reviews"
  on public.business_reviews for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.account_type = 'admin'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.account_type = 'admin'));
