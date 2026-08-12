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
--   5. 20260814_business_media_owner_access.sql
--   6. 20260815_community_news_author_read.sql
--   7. 20260815_news_spark_public_read.sql
--   8. 20260816_user_saved_items.sql
--   9. 20260816_rental_admin_and_message_search.sql
--  10. 20260816_feed_comments_text_media_id.sql
--
-- Prerequisite (run separately if news feed tables missing):
--   20260813_menus_news_feed.sql

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

-- =============================================================================
-- 5. business_media_owner_access
-- =============================================================================

update storage.buckets
set
  allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif',
    'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
    'video/x-matroska', 'video/x-m4v'
  ]
where id = 'business-media';

drop policy if exists "Owners view their business media files" on storage.objects;
create policy "Owners view their business media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'business-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.business_media media
        join public.businesses business on business.id = media.business_id
        where media.storage_path = name
          and business.created_by = auth.uid()
      )
    )
  );

drop policy if exists "Owners read their business media records" on public.business_media;
create policy "Owners read their business media records"
  on public.business_media for select to authenticated
  using (
    exists (
      select 1 from public.businesses business
      where business.id = business_id and business.created_by = auth.uid()
    )
  );

-- =============================================================================
-- 6. community_news_author_read
-- =============================================================================

drop policy if exists "Authors read their news posts" on public.community_news_posts;
create policy "Authors read their news posts"
  on public.community_news_posts for select to authenticated
  using (author_id = auth.uid());

-- =============================================================================
-- 7. news_spark_public_read
-- =============================================================================

drop policy if exists "Public reads news spark counts" on public.community_news_post_sparks;
create policy "Public reads news spark counts"
  on public.community_news_post_sparks for select
  using (true);

-- =============================================================================
-- 8. user_saved_items
-- =============================================================================

create table if not exists public.user_saved_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('news_post', 'business')),
  content_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

alter table public.user_saved_items enable row level security;

drop policy if exists "Users read own saved items" on public.user_saved_items;
create policy "Users read own saved items"
  on public.user_saved_items for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users save items" on public.user_saved_items;
create policy "Users save items"
  on public.user_saved_items for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users unsave items" on public.user_saved_items;
create policy "Users unsave items"
  on public.user_saved_items for delete to authenticated
  using (user_id = auth.uid());

create index if not exists user_saved_items_user_created_idx
  on public.user_saved_items (user_id, created_at desc);

-- =============================================================================
-- 9. rental_admin_and_message_search
-- Requires is_firstvue_admin() from 20260811_phase1_security_hardening.sql
-- =============================================================================

drop policy if exists "FirstVue admins manage rentals" on public.rentals;
create policy "FirstVue admins manage rentals"
  on public.rentals for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins manage rental media" on public.rental_media;
drop policy if exists "FirstVue admins manage rental media records" on public.rental_media;
create policy "FirstVue admins manage rental media"
  on public.rental_media for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins read rental media files" on storage.objects;
drop policy if exists "FirstVue admins view rental media files" on storage.objects;
create policy "FirstVue admins read rental media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'rental-media'
    and public.is_firstvue_admin()
  );

drop policy if exists "FirstVue admins read pending rentals" on public.rentals;
create policy "FirstVue admins read pending rentals"
  on public.rentals for select to authenticated
  using (public.is_firstvue_admin() and status = 'pending');

create or replace function public.search_message_recipients(search_query text)
returns table (
  profile_id uuid,
  display_name text,
  account_type text,
  business_id uuid,
  business_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select distinct on (p.id)
    p.id as profile_id,
    p.display_name,
    p.account_type,
    b.id as business_id,
    b.name as business_name
  from public.profiles p
  left join public.businesses b
    on b.created_by = p.id
   and b.status = 'approved'
  left join auth.users u on u.id = p.id
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.display_name is not null
    and char_length(trim(search_query)) >= 2
    and (
      p.display_name ilike '%' || trim(search_query) || '%'
      or u.email ilike '%' || trim(search_query) || '%'
    )
  order by p.id, b.created_at desc nulls last
  limit 25;
$$;

revoke all on function public.search_message_recipients(text) from public;
grant execute on function public.search_message_recipients(text) to authenticated;

-- =============================================================================
-- 10. feed_comments_text_media_id
-- Requires feed_comments from 20260811_messaging_and_comments.sql
-- and community_news_posts from 20260813_menus_news_feed.sql
-- =============================================================================

-- We avoid ALTER COLUMN ... TYPE (blocked by RLS policies). Add text column, copy,
-- drop uuid column CASCADE, rename, recreate policies.

alter table public.feed_comments
  drop constraint if exists feed_comments_media_id_fkey;

alter table public.feed_comments
  add column if not exists media_id_text text;

update public.feed_comments
set media_id_text = media_id::text
where media_id_text is null;

alter table public.feed_comments
  drop column if exists media_id cascade;

alter table public.feed_comments
  rename column media_id_text to media_id;

alter table public.feed_comments
  alter column media_id set not null;

create or replace function public.feed_comment_target_is_commentable(p_media_id text)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    case
      when p_media_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        exists (
          select 1
          from public.business_media m
          join public.businesses b on b.id = m.business_id
          where m.id::text = p_media_id
            and b.status = 'approved'
        )
      when p_media_id like 'news-post:%' then
        exists (
          select 1
          from public.community_news_posts p
          where p.id::text = split_part(p_media_id, ':', 2)
            and (
              p.status = 'approved'
              or p.author_id = auth.uid()
            )
        )
      when p_media_id like 'meet-owner:%' then
        exists (
          select 1
          from public.businesses b
          where b.id::text = split_part(p_media_id, ':', 2)
            and b.status = 'approved'
        )
      else false
    end;
$$;

drop policy if exists "Authenticated users read feed comments" on public.feed_comments;
drop policy if exists "Authenticated users post feed comments" on public.feed_comments;
drop policy if exists "Authors delete their feed comments" on public.feed_comments;

create policy "Authenticated users read feed comments"
  on public.feed_comments for select to authenticated
  using (public.feed_comment_target_is_commentable(media_id));

create policy "Authenticated users post feed comments"
  on public.feed_comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.feed_comment_target_is_commentable(media_id)
  );

create policy "Authors delete their feed comments"
  on public.feed_comments for delete to authenticated
  using (author_id = auth.uid());

-- =============================================================================
-- 11. community_news_post_media (20260817)
-- Photos and videos on news feed posts
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-news-media',
  'community-news-media',
  false,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/bmp',
    'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
    'video/x-matroska', 'video/x-m4v'
  ]
)
on conflict (id) do update
set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.community_news_post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  storage_path text not null unique,
  storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3')),
  media_type text not null default 'image'
    check (media_type in ('image', 'video')),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.community_news_post_media enable row level security;

drop policy if exists "Authors manage their news post media" on public.community_news_post_media;
create policy "Authors manage their news post media"
  on public.community_news_post_media for all to authenticated
  using (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.author_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.author_id = auth.uid()
    )
  );

drop policy if exists "Public reads approved news post media" on public.community_news_post_media;
create policy "Public reads approved news post media"
  on public.community_news_post_media for select
  using (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.status = 'approved'
    )
  );

drop policy if exists "Authors read their news post media" on public.community_news_post_media;
create policy "Authors read their news post media"
  on public.community_news_post_media for select to authenticated
  using (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.author_id = auth.uid()
    )
  );

drop policy if exists "Authors upload news post media" on storage.objects;
create policy "Authors upload news post media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'community-news-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Authors delete news post media files" on storage.objects;
create policy "Authors delete news post media files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'community-news-media'
    and owner_id = auth.uid()::text
  );

drop policy if exists "Public reads approved news post media files" on storage.objects;
create policy "Public reads approved news post media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'community-news-media'
    and exists (
      select 1
      from public.community_news_post_media media
      join public.community_news_posts post on post.id = media.post_id
      where media.storage_path = name and post.status = 'approved'
    )
  );

drop policy if exists "Authors view their news post media files" on storage.objects;
create policy "Authors view their news post media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'community-news-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.community_news_post_media media
        join public.community_news_posts post on post.id = media.post_id
        where media.storage_path = name and post.author_id = auth.uid()
      )
    )
  );

create index if not exists community_news_post_media_post_idx
  on public.community_news_post_media (post_id, sort_order);

-- =============================================================================
-- 12. profile_media_trending_featured (20260818)
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-media',
  'profile-media',
  false,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/bmp',
    'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
    'video/x-matroska', 'video/x-m4v'
  ]
)
on conflict (id) do update
set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.profile_media (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3')),
  media_type text not null default 'image'
    check (media_type in ('image', 'video')),
  featured_for_trending boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profile_media enable row level security;

drop policy if exists "Users manage their profile media" on public.profile_media;
create policy "Users manage their profile media"
  on public.profile_media for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Authenticated users read profile media" on public.profile_media;
create policy "Authenticated users read profile media"
  on public.profile_media for select to authenticated
  using (true);

alter table public.business_media
  add column if not exists featured_for_trending boolean not null default false;

alter table public.professional_media
  add column if not exists storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3'));

alter table public.professional_media
  add column if not exists media_type text not null default 'image'
    check (media_type in ('image', 'video'));

alter table public.professional_media
  add column if not exists featured_for_trending boolean not null default false;

update storage.buckets
set allowed_mime_types = array[
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/bmp',
  'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
  'video/x-matroska', 'video/x-m4v'
]
where id = 'professional-media';

drop policy if exists "Professionals view their portfolio files" on storage.objects;
create policy "Professionals view their portfolio files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'professional-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.professional_media media
        join public.professional_profiles professional
          on professional.id = media.professional_profile_id
        where media.storage_path = name
          and professional.profile_id = auth.uid()
      )
    )
  );

drop policy if exists "Users upload profile media" on storage.objects;
create policy "Users upload profile media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users delete profile media files" on storage.objects;
create policy "Users delete profile media files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-media'
    and owner_id = auth.uid()::text
  );

drop policy if exists "Authenticated users read profile media files" on storage.objects;
create policy "Authenticated users read profile media files"
  on storage.objects for select to authenticated
  using (bucket_id = 'profile-media');

create index if not exists profile_media_profile_idx
  on public.profile_media (profile_id, sort_order);

create index if not exists business_media_trending_idx
  on public.business_media (business_id, featured_for_trending)
  where featured_for_trending = true;

create index if not exists professional_media_trending_idx
  on public.professional_media (professional_profile_id, featured_for_trending)
  where featured_for_trending = true;

-- =============================================================================
-- 13. profile_avatar_cover (20260819)
-- Avatar/cover roles on profile_media; storage_bucket on news post media
-- Includes 20260817/20260818 prerequisites if not yet applied.
--
-- In Supabase SQL Editor, open and run the FULL file:
--   supabase/migrations/20260819_profile_avatar_cover.sql
-- (Do not run section 13 alone — it depends on tables created in that file.)
-- =============================================================================

