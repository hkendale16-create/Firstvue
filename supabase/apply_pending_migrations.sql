-- FIRSTVUE: Apply all pending migrations in one Supabase SQL Editor session.
-- Run AFTER the Aug 10 batch (through 20260811_professional_profiles.sql).
--
-- Dashboard: https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new
--
-- Sections below mirror these files in order:
--   1. 20260811_professional_media_availability.sql
--   2. 20260811_professional_showcase.sql
--   3. 20260811_social_discovery_monetization.sql
--   4. 20260811_ai_commerce_owner_connections.sql

-- =============================================================================
-- 1. professional_media_availability
-- =============================================================================

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

-- =============================================================================
-- 2. professional_showcase
-- =============================================================================

create table if not exists public.professional_social_links (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  platform text not null
    check (platform in ('instagram', 'tiktok', 'youtube', 'facebook', 'website', 'other')),
  label text not null default '' check (char_length(label) <= 80),
  url text not null check (char_length(url) between 8 and 500),
  source text not null default 'link' check (source in ('link', 'connected')),
  connected_external_id text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.professional_social_posts (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  platform text not null
    check (platform in ('instagram', 'tiktok', 'youtube', 'facebook', 'other')),
  post_url text not null check (char_length(post_url) between 8 and 500),
  caption text not null default '' check (char_length(caption) <= 500),
  source text not null default 'link' check (source in ('link', 'connected')),
  connected_external_id text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.professional_catalog_items (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text not null default '' check (char_length(description) <= 1000),
  price_label text not null default '' check (char_length(price_label) <= 60),
  image_url text not null default '' check (char_length(image_url) <= 500),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.professional_social_links enable row level security;
alter table public.professional_social_posts enable row level security;
alter table public.professional_catalog_items enable row level security;

drop policy if exists "Professionals manage their social links" on public.professional_social_links;
drop policy if exists "Public reads approved professional social links" on public.professional_social_links;
drop policy if exists "Professionals manage their linked social posts" on public.professional_social_posts;
drop policy if exists "Public reads approved professional social posts" on public.professional_social_posts;
drop policy if exists "Professionals manage their catalog" on public.professional_catalog_items;
drop policy if exists "Public reads approved professional catalog" on public.professional_catalog_items;

create policy "Professionals manage their social links"
  on public.professional_social_links for all to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  )
  with check (
    source = 'link'
    and exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  );

create policy "Public reads approved professional social links"
  on public.professional_social_links for select
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create policy "Professionals manage their linked social posts"
  on public.professional_social_posts for all to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  )
  with check (
    source = 'link'
    and exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  );

create policy "Public reads approved professional social posts"
  on public.professional_social_posts for select
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create policy "Professionals manage their catalog"
  on public.professional_catalog_items for all to authenticated
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

create policy "Public reads approved professional catalog"
  on public.professional_catalog_items for select
  using (
    is_active
    and exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create index if not exists professional_social_links_profile_idx
  on public.professional_social_links (professional_profile_id, sort_order);
create index if not exists professional_social_posts_profile_idx
  on public.professional_social_posts (professional_profile_id, sort_order);
create index if not exists professional_catalog_profile_idx
  on public.professional_catalog_items (professional_profile_id, is_active, sort_order);

-- =============================================================================
-- 3. social_discovery_monetization
-- =============================================================================

alter table public.business_media add column if not exists media_type text not null default 'image' check (media_type in ('image', 'video'));
alter table public.business_media add column if not exists caption text;
alter table public.business_media add column if not exists duration_seconds integer check (duration_seconds is null or duration_seconds between 1 and 90);
alter table public.business_media add column if not exists thumbnail_path text;
alter table public.business_media add column if not exists is_profile_media boolean not null default false;

alter table public.businesses add column if not exists plan text not null default 'basic' check (plan in ('basic', 'verified', 'pro'));
alter table public.businesses add column if not exists popularity_score double precision not null default 0;
alter table public.businesses add column if not exists demand_score double precision not null default 0;
alter table public.businesses add column if not exists average_rating numeric(2,1);
alter table public.businesses add column if not exists price_level integer check (price_level between 1 and 4);
alter table public.businesses add column if not exists external_source text;
alter table public.businesses add column if not exists external_place_id text;
alter table public.businesses add column if not exists external_refreshed_at timestamptz;

create table if not exists public.feed_engagements (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.business_media(id) on delete cascade,
  event_type text not null check (event_type in ('impression', 'view', 'like', 'save', 'share', 'profile_tap', 'booking_tap')),
  watch_ms integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.business_promotions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  campaign_type text not null check (campaign_type in ('featured', 'sponsored_search', 'feed')),
  billing_model text not null check (billing_model in ('flat', 'cpc', 'cpm')),
  budget_cents integer not null check (budget_cents > 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.feed_engagements enable row level security;
alter table public.business_promotions enable row level security;

drop policy if exists "Users create their feed engagement" on public.feed_engagements;
drop policy if exists "Users read their feed engagement" on public.feed_engagements;
drop policy if exists "Public can read active promotions" on public.business_promotions;
drop policy if exists "Public can view approved feed media" on public.business_media;
drop policy if exists "Public can view approved feed files" on storage.objects;

create policy "Users create their feed engagement" on public.feed_engagements for insert to authenticated with check (profile_id = auth.uid());
create policy "Users read their feed engagement" on public.feed_engagements for select to authenticated using (profile_id = auth.uid());
create policy "Public can read active promotions" on public.business_promotions for select using (is_active and now() between starts_at and ends_at);

create policy "Public can view approved feed media" on public.business_media
  for select to anon using (exists (
    select 1 from public.businesses b
    where b.id = business_id and b.status = 'approved'
  ));
create policy "Public can view approved feed files" on storage.objects
  for select to anon using (bucket_id = 'business-media' and exists (
    select 1 from public.business_media m
    join public.businesses b on b.id = m.business_id
    where m.storage_path = name and b.status = 'approved'
  ));

create index if not exists business_discovery_rank_idx on public.businesses (status, popularity_score desc, demand_score desc);
create index if not exists business_location_geo_idx on public.business_locations (latitude, longitude);
create index if not exists feed_media_idx on public.business_media (media_type, created_at desc);

-- =============================================================================
-- 4. ai_commerce_owner_connections
-- =============================================================================

alter table public.businesses add column if not exists minimum_price_cents integer check (minimum_price_cents is null or minimum_price_cents >= 0);
alter table public.businesses add column if not exists available_today boolean not null default false;
alter table public.businesses add column if not exists accepts_bookings boolean not null default false;
alter table public.businesses add column if not exists phone text;
alter table public.businesses add column if not exists website_url text;
alter table public.businesses add column if not exists outdoor_seating boolean not null default false;

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

create or replace view public.business_discovery_view with (security_invoker = true) as
select b.id, b.name, b.business_type, b.description, b.services,
       b.average_rating, b.minimum_price_cents, b.available_today,
       b.outdoor_seating, b.verification_status, b.popularity_score,
       b.demand_score, l.city, l.state, l.latitude, l.longitude
from public.businesses b
left join public.business_locations l on l.business_id = b.id
where b.status = 'approved';
