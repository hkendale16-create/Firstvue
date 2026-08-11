-- Social discovery, ranking and monetization primitives. FirstVue-owned data is
-- the source of truth; third-party place data should only be refreshed on demand.
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

-- Policies cannot use CREATE IF NOT EXISTS in PostgreSQL. Drop by exact name so
-- this migration remains safe to rerun after a partial Dashboard execution.
drop policy if exists "Users create their feed engagement" on public.feed_engagements;
drop policy if exists "Users read their feed engagement" on public.feed_engagements;
drop policy if exists "Public can read active promotions" on public.business_promotions;
drop policy if exists "Public can view approved feed media" on public.business_media;
drop policy if exists "Public can view approved feed files" on storage.objects;

create policy "Users create their feed engagement" on public.feed_engagements for insert to authenticated with check (profile_id = auth.uid());
create policy "Users read their feed engagement" on public.feed_engagements for select to authenticated using (profile_id = auth.uid());
create policy "Public can read active promotions" on public.business_promotions for select using (is_active and now() between starts_at and ends_at);

-- Discovery is public. Signed URLs remain short-lived and only expose media for
-- approved businesses.
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
