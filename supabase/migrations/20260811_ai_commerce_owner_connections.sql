-- Owner-connected publishing, FirstVue-native AI discovery and commerce.
alter table public.businesses add column if not exists minimum_price_cents integer check (minimum_price_cents is null or minimum_price_cents >= 0);
alter table public.businesses add column if not exists available_today boolean not null default false;
alter table public.businesses add column if not exists accepts_bookings boolean not null default false;
alter table public.businesses add column if not exists phone text;
alter table public.businesses add column if not exists website_url text;
alter table public.businesses add column if not exists outdoor_seating boolean not null default false;

-- A feed post is always owned through business_media.business_id ->
-- businesses.created_by. Owners cannot publish against somebody else's business.
drop policy if exists "Owners manage their business media records" on public.business_media;
create policy "Owners manage their business media records" on public.business_media
  for all to authenticated
  using (exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()))
  with check (exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()));

drop policy if exists "Public can read owner display identities" on public.profiles;
create policy "Public can read owner display identities" on public.profiles
  for select to anon, authenticated using (display_name is not null);

create table if not exists public.business_services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text,
  price_cents integer check (price_cents is null or price_cents >= 0),
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.business_subscriptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  plan text not null check (plan in ('basic', 'verified', 'pro')),
  price_cents integer not null default 0,
  status text not null default 'active' check (status in ('trialing', 'active', 'past_due', 'canceled')),
  provider_customer_id text,
  provider_subscription_id text,
  current_period_ends_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.business_leads (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  requester_id uuid references public.profiles(id) on delete set null,
  source text not null check (source in ('search', 'feed', 'profile', 'campaign')),
  message text,
  status text not null default 'new' check (status in ('new', 'contacted', 'converted', 'closed')),
  billable_amount_cents integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  service_id uuid references public.business_services(id) on delete set null,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  starts_at timestamptz not null,
  subtotal_cents integer not null check (subtotal_cents >= 0),
  platform_fee_cents integer not null default 0 check (platform_fee_cents >= 0),
  status text not null default 'requested' check (status in ('requested', 'confirmed', 'completed', 'canceled')),
  created_at timestamptz not null default now()
);

create table if not exists public.business_follows (
  business_id uuid not null references public.businesses(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (business_id, profile_id)
);

alter table public.business_services enable row level security;
alter table public.business_subscriptions enable row level security;
alter table public.business_leads enable row level security;
alter table public.bookings enable row level security;
alter table public.business_follows enable row level security;

drop policy if exists "Public reads active services" on public.business_services;
drop policy if exists "Owners manage services" on public.business_services;
drop policy if exists "Owners read subscriptions" on public.business_subscriptions;
drop policy if exists "Customers create leads" on public.business_leads;
drop policy if exists "Owners read leads" on public.business_leads;
drop policy if exists "Customers create bookings" on public.bookings;
drop policy if exists "Booking participants read bookings" on public.bookings;
drop policy if exists "Users manage follows" on public.business_follows;

create policy "Public reads active services" on public.business_services for select using (is_active);
create policy "Owners manage services" on public.business_services for all to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid())) with check (exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()));
create policy "Owners read subscriptions" on public.business_subscriptions for select to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()));
create policy "Customers create leads" on public.business_leads for insert to authenticated with check (requester_id = auth.uid());
create policy "Owners read leads" on public.business_leads for select to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()));
create policy "Customers create bookings" on public.bookings for insert to authenticated with check (customer_id = auth.uid());
create policy "Booking participants read bookings" on public.bookings for select to authenticated using (customer_id = auth.uid() or exists (select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()));
create policy "Users manage follows" on public.business_follows for all to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create index if not exists business_services_search_idx on public.business_services using gin (to_tsvector('english', name || ' ' || coalesce(description, '')));
create index if not exists business_leads_owner_idx on public.business_leads (business_id, created_at desc);
create index if not exists bookings_business_time_idx on public.bookings (business_id, starts_at);

-- This view is the server-side source for AI/ranked discovery. It reads only
-- FirstVue-owned records. External place IDs remain optional cached enrichment.
create or replace view public.business_discovery_view with (security_invoker = true) as
select b.id, b.name, b.business_type, b.description, b.services,
       b.average_rating, b.minimum_price_cents, b.available_today,
       b.outdoor_seating, b.verification_status, b.popularity_score,
       b.demand_score, l.city, l.state, l.latitude, l.longitude
from public.businesses b
left join public.business_locations l on l.business_id = b.id
where b.status = 'approved';
