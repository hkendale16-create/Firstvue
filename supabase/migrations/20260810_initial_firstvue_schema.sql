-- FIRSTVUE initial ecosystem schema.
-- Run in Supabase Dashboard > SQL Editor. All application tables use RLS.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  account_type text not null default 'customer'
    check (account_type in ('customer', 'professional', 'business_owner', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.industries (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  industry_id uuid not null references public.industries(id) on delete cascade,
  name text not null,
  slug text not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.categories(id),
  name text not null,
  description text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified', 'pending', 'verified', 'rejected')),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_locations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  address_line_1 text,
  city text,
  state text,
  postal_code text,
  country_code text not null default 'US',
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

create table if not exists public.business_memberships (
  business_id uuid not null references public.businesses(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'manager', 'staff')),
  created_at timestamptz not null default now(),
  primary key (business_id, profile_id)
);

create table if not exists public.business_claims (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  claimant_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create table if not exists public.rentals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  title text not null,
  description text,
  city text,
  state text,
  postal_code text,
  weekly_price_cents integer check (weekly_price_cents is null or weekly_price_cents >= 0),
  monthly_price_cents integer check (monthly_price_cents is null or monthly_price_cents >= 0),
  audience text not null default 'professionals'
    check (audience in ('professionals', 'opted_in_customers')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rental_media (
  id uuid primary key default gen_random_uuid(),
  rental_id uuid not null references public.rentals(id) on delete cascade,
  storage_path text not null,
  media_type text not null check (media_type in ('image', 'video')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.rental_access_consents (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  agreement_version text not null,
  accepted_at timestamptz not null default now()
);

create table if not exists public.rental_inquiries (
  id uuid primary key default gen_random_uuid(),
  rental_id uuid not null references public.rentals(id) on delete cascade,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  message text,
  status text not null default 'new'
    check (status in ('new', 'read', 'closed')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.industries enable row level security;
alter table public.categories enable row level security;
alter table public.businesses enable row level security;
alter table public.business_locations enable row level security;
alter table public.business_memberships enable row level security;
alter table public.business_claims enable row level security;
alter table public.rentals enable row level security;
alter table public.rental_media enable row level security;
alter table public.rental_access_consents enable row level security;
alter table public.rental_inquiries enable row level security;

create policy "Public can read active industries"
  on public.industries for select using (is_active);
create policy "Public can read active categories"
  on public.categories for select using (is_active);
create policy "Public can read approved businesses"
  on public.businesses for select using (status = 'approved');
create policy "Public can read approved business locations"
  on public.business_locations for select using (
    exists (select 1 from public.businesses b where b.id = business_id and b.status = 'approved')
  );

create policy "Users manage their own profile"
  on public.profiles for all to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "Users create their own claims"
  on public.business_claims for insert to authenticated with check (claimant_id = auth.uid());
create policy "Users read their own claims"
  on public.business_claims for select to authenticated using (claimant_id = auth.uid());
create policy "Owners manage their rentals"
  on public.rentals for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "Authenticated users view approved rentals"
  on public.rentals for select to authenticated using (status = 'approved');
create policy "Owners manage rental media"
  on public.rental_media for all to authenticated using (
    exists (select 1 from public.rentals r where r.id = rental_id and r.owner_id = auth.uid())
  ) with check (
    exists (select 1 from public.rentals r where r.id = rental_id and r.owner_id = auth.uid())
  );
create policy "Users manage their own rental consent"
  on public.rental_access_consents for all to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "Users create their own rental inquiries"
  on public.rental_inquiries for insert to authenticated with check (requester_id = auth.uid());
create policy "Users read their own rental inquiries"
  on public.rental_inquiries for select to authenticated using (requester_id = auth.uid());

insert into public.industries (name, slug) values
  ('Beauty & Personal Care', 'beauty-personal-care'),
  ('Automotive', 'automotive'),
  ('Home Services', 'home-services'),
  ('Fitness & Wellness', 'fitness-wellness'),
  ('Pet Services', 'pet-services')
on conflict (slug) do nothing;
