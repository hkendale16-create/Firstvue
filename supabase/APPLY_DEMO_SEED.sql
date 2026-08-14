-- =============================================================================
-- FirstVue DEMO SEED — 25 people + posts + businesses + events
-- Paste into Supabase SQL Editor and Run (service role / dashboard).
-- Safe to re-run: purges prior fvdemo_* pack first, then reseeds.
-- Marker: profiles.is_demo = true AND username like 'fvdemo_%'
-- Purge later with: supabase/APPLY_DEMO_PURGE.sql
-- Dashboard: https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new
-- =============================================================================

begin;

-- Ensure demo marker + external media provider support exist.
alter table public.profiles
  add column if not exists is_demo boolean not null default false;

-- Signup acceptance columns (from 20260919) — may be missing on older DBs.
alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz;

alter table public.businesses
  add column if not exists is_demo boolean not null default false;

alter table public.community_events
  add column if not exists is_demo boolean not null default false;

alter table public.community_news_posts
  add column if not exists is_demo boolean not null default false;

do $$
begin
  -- profile_media.storage_provider
  if exists (
    select 1 from information_schema.table_constraints
    where table_schema = 'public' and table_name = 'profile_media'
      and constraint_name = 'profile_media_storage_provider_check'
  ) then
    alter table public.profile_media drop constraint profile_media_storage_provider_check;
  end if;
  alter table public.profile_media
    add constraint profile_media_storage_provider_check
    check (storage_provider in ('supabase', 's3', 'external'));

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'business_media'
      and column_name = 'storage_provider'
  ) then
    begin
      alter table public.business_media drop constraint if exists business_media_storage_provider_check;
    exception when undefined_object then null;
    end;
    alter table public.business_media
      drop constraint if exists business_media_storage_provider_check;
    alter table public.business_media
      add constraint business_media_storage_provider_check
      check (storage_provider in ('supabase', 's3', 'external'));
  else
    alter table public.business_media
      add column if not exists storage_provider text not null default 'supabase';
    alter table public.business_media
      drop constraint if exists business_media_storage_provider_check;
    alter table public.business_media
      add constraint business_media_storage_provider_check
      check (storage_provider in ('supabase', 's3', 'external'));
  end if;

  alter table public.business_media
    add column if not exists media_type text not null default 'image';
  alter table public.business_media
    add column if not exists caption text;
  alter table public.business_media
    add column if not exists thumbnail_path text;
  alter table public.business_media
    add column if not exists featured_for_trending boolean not null default false;

  if exists (
    select 1 from information_schema.table_constraints
    where table_schema = 'public' and table_name = 'community_news_post_media'
      and constraint_name = 'community_news_post_media_storage_provider_check'
  ) then
    alter table public.community_news_post_media
      drop constraint community_news_post_media_storage_provider_check;
  end if;
  alter table public.community_news_post_media
    drop constraint if exists community_news_post_media_storage_provider_check;
  alter table public.community_news_post_media
    add constraint community_news_post_media_storage_provider_check
    check (storage_provider in ('supabase', 's3', 'external'));
end $$;

-- Wipe previous demo pack (auth delete cascades profiles + dependents).
-- Match by fixed demo UUIDs / emails too — a partial prior run can leave
-- auth.users without profiles, which would skip purge if we only look at profiles.
do $$
declare
  demo_ids uuid[] := array[
    'a0000000-0000-4000-8000-000000000001'::uuid,
    'a0000000-0000-4000-8000-000000000002'::uuid,
    'a0000000-0000-4000-8000-000000000003'::uuid,
    'a0000000-0000-4000-8000-000000000004'::uuid,
    'a0000000-0000-4000-8000-000000000005'::uuid,
    'a0000000-0000-4000-8000-000000000006'::uuid,
    'a0000000-0000-4000-8000-000000000007'::uuid,
    'a0000000-0000-4000-8000-000000000008'::uuid,
    'a0000000-0000-4000-8000-000000000009'::uuid,
    'a0000000-0000-4000-8000-000000000010'::uuid,
    'a0000000-0000-4000-8000-000000000011'::uuid,
    'a0000000-0000-4000-8000-000000000012'::uuid,
    'a0000000-0000-4000-8000-000000000013'::uuid,
    'a0000000-0000-4000-8000-000000000014'::uuid,
    'a0000000-0000-4000-8000-000000000015'::uuid,
    'a0000000-0000-4000-8000-000000000016'::uuid,
    'a0000000-0000-4000-8000-000000000017'::uuid,
    'a0000000-0000-4000-8000-000000000018'::uuid,
    'a0000000-0000-4000-8000-000000000019'::uuid,
    'a0000000-0000-4000-8000-000000000020'::uuid,
    'a0000000-0000-4000-8000-000000000021'::uuid,
    'a0000000-0000-4000-8000-000000000022'::uuid,
    'a0000000-0000-4000-8000-000000000023'::uuid,
    'a0000000-0000-4000-8000-000000000024'::uuid,
    'a0000000-0000-4000-8000-000000000025'::uuid
  ];
  extra_ids uuid[];
begin
  select coalesce(array_agg(id), '{}') into extra_ids
  from public.profiles
  where is_demo = true or username like 'fvdemo_%';

  demo_ids := (select array_agg(distinct x) from unnest(demo_ids || extra_ids) as x);

  delete from public.community_news_posts
  where is_demo = true or author_id = any(demo_ids);
  delete from public.community_events
  where is_demo = true or organizer_id = any(demo_ids);
  delete from public.businesses
  where is_demo = true or created_by = any(demo_ids);
  delete from auth.users
  where id = any(demo_ids) or email like '%@firstvue.demo';
end $$;

create temporary table _fv_demo (
  n int primary key,
  id uuid not null unique,
  email text not null unique,
  username text not null unique,
  display_name text not null,
  bio text not null,
  city text not null,
  state text not null,
  account_type text not null default 'customer'
) on commit drop;

insert into _fv_demo (n, id, email, username, display_name, bio, city, state, account_type) values
  (1, 'a0000000-0000-4000-8000-000000000001'::uuid, 'fvdemo01@firstvue.demo', 'fvdemo_maya', 'Maya Chen', 'ATL stylist. Soft glam and natural texture specialist.', 'Atlanta', 'GA', 'professional'),
  (2, 'a0000000-0000-4000-8000-000000000002'::uuid, 'fvdemo02@firstvue.demo', 'fvdemo_jordan', 'Jordan Blake', 'Barber and fade artist. Midtown chair.', 'Atlanta', 'GA', 'professional'),
  (3, 'a0000000-0000-4000-8000-000000000003'::uuid, 'fvdemo03@firstvue.demo', 'fvdemo_aaliyah', 'Aaliyah Brooks', 'Bridal makeup and soft glam for every skin tone.', 'Decatur', 'GA', 'professional'),
  (4, 'a0000000-0000-4000-8000-000000000004'::uuid, 'fvdemo04@firstvue.demo', 'fvdemo_chris', 'Chris Nguyen', 'Nail tech who loves clean chrome and classic french.', 'Atlanta', 'GA', 'professional'),
  (5, 'a0000000-0000-4000-8000-000000000005'::uuid, 'fvdemo05@firstvue.demo', 'fvdemo_sofia', 'Sofia Ramirez', 'Lash artist. Volume, hybrid, and classic sets.', 'Sandy Springs', 'GA', 'professional'),
  (6, 'a0000000-0000-4000-8000-000000000006'::uuid, 'fvdemo06@firstvue.demo', 'fvdemo_marcus', 'Marcus Webb', 'Tattoo apprentice documenting flash and fine line.', 'Atlanta', 'GA', 'customer'),
  (7, 'a0000000-0000-4000-8000-000000000007'::uuid, 'fvdemo07@firstvue.demo', 'fvdemo_priya', 'Priya Shah', 'Skin-first esthetician. Hydrafacials and glow routines.', 'Brookhaven', 'GA', 'professional'),
  (8, 'a0000000-0000-4000-8000-000000000008'::uuid, 'fvdemo08@firstvue.demo', 'fvdemo_elena', 'Elena Vargas', 'Color specialist. Lived-in blondes and rich brunettes.', 'Atlanta', 'GA', 'professional'),
  (9, 'a0000000-0000-4000-8000-000000000009'::uuid, 'fvdemo09@firstvue.demo', 'fvdemo_devon', 'Devon Price', 'Personal trainer who films quick mobility flows.', 'East Point', 'GA', 'customer'),
  (10, 'a0000000-0000-4000-8000-000000000010'::uuid, 'fvdemo10@firstvue.demo', 'fvdemo_naomi', 'Naomi Okonkwo', 'Natural hair educator. Twist-outs and protective styles.', 'Atlanta', 'GA', 'professional'),
  (11, 'a0000000-0000-4000-8000-000000000011'::uuid, 'fvdemo11@firstvue.demo', 'fvdemo_leo', 'Leo Kim', 'Photographer capturing nightlife and portraits.', 'Atlanta', 'GA', 'customer'),
  (12, 'a0000000-0000-4000-8000-000000000012'::uuid, 'fvdemo12@firstvue.demo', 'fvdemo_harper', 'Harper Quinn', 'Boutique owner sharing weekly drop previews.', 'Buckhead', 'GA', 'business_owner'),
  (13, 'a0000000-0000-4000-8000-000000000013'::uuid, 'fvdemo13@firstvue.demo', 'fvdemo_isaiah', 'Isaiah Ford', 'Chef plating weekend pop-up dinners.', 'Atlanta', 'GA', 'business_owner'),
  (14, 'a0000000-0000-4000-8000-000000000014'::uuid, 'fvdemo14@firstvue.demo', 'fvdemo_riley', 'Riley Santos', 'Event planner for intimate rooftop nights.', 'Atlanta', 'GA', 'business_owner'),
  (15, 'a0000000-0000-4000-8000-000000000015'::uuid, 'fvdemo15@firstvue.demo', 'fvdemo_zoe', 'Zoe Patel', 'Wellness coach. Breathwork and morning routines.', 'Roswell', 'GA', 'customer'),
  (16, 'a0000000-0000-4000-8000-000000000016'::uuid, 'fvdemo16@firstvue.demo', 'fvdemo_andre', 'Andre Miles', 'Sneaker curator and streetwear stylist.', 'Atlanta', 'GA', 'customer'),
  (17, 'a0000000-0000-4000-8000-000000000017'::uuid, 'fvdemo17@firstvue.demo', 'fvdemo_camila', 'Camila Ortiz', 'Dance instructor posting class energy clips.', 'Atlanta', 'GA', 'customer'),
  (18, 'a0000000-0000-4000-8000-000000000018'::uuid, 'fvdemo18@firstvue.demo', 'fvdemo_noah', 'Noah Ellis', 'DJ and playlist curator for local lounges.', 'Atlanta', 'GA', 'customer'),
  (19, 'a0000000-0000-4000-8000-000000000019'::uuid, 'fvdemo19@firstvue.demo', 'fvdemo_jade', 'Jade Thompson', 'Fashion student documenting thrift finds.', 'Atlanta', 'GA', 'customer'),
  (20, 'a0000000-0000-4000-8000-000000000020'::uuid, 'fvdemo20@firstvue.demo', 'fvdemo_omar', 'Omar Hassan', 'Coffee roaster sharing pour-over notes.', 'Decatur', 'GA', 'business_owner'),
  (21, 'a0000000-0000-4000-8000-000000000021'::uuid, 'fvdemo21@firstvue.demo', 'fvdemo_bianca', 'Bianca Cole', 'Spa owner focused on quiet luxury rituals.', 'Atlanta', 'GA', 'business_owner'),
  (22, 'a0000000-0000-4000-8000-000000000022'::uuid, 'fvdemo22@firstvue.demo', 'fvdemo_tyler', 'Tyler Reed', 'Realtor highlighting new ATL listings.', 'Atlanta', 'GA', 'customer'),
  (23, 'a0000000-0000-4000-8000-000000000023'::uuid, 'fvdemo23@firstvue.demo', 'fvdemo_sana', 'Sana Ali', 'Henna artist for weddings and festivals.', 'Atlanta', 'GA', 'professional'),
  (24, 'a0000000-0000-4000-8000-000000000024'::uuid, 'fvdemo24@firstvue.demo', 'fvdemo_kai', 'Kai Johnson', 'Creator filming day-in-the-life around town.', 'Atlanta', 'GA', 'customer'),
  (25, 'a0000000-0000-4000-8000-000000000025'::uuid, 'fvdemo25@firstvue.demo', 'fvdemo_nina', 'Nina Brooks', 'Community host connecting makers and markets.', 'Atlanta', 'GA', 'customer');

-- Create auth users (trigger builds profiles).
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token,
  is_super_admin
)
select
  coalesce((select id from auth.instances limit 1), '00000000-0000-0000-0000-000000000000'::uuid),
  d.id,
  'authenticated',
  'authenticated',
  d.email,
  crypt('FirstVueDemo!25', gen_salt('bf')),
  now(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'is_demo', true
  ),
  jsonb_build_object(
    'username', d.username,
    'terms_accepted', true,
    'privacy_accepted', true,
    'full_name', d.display_name
  ),
  now(),
  now(),
  '',
  '',
  '',
  '',
  false
from _fv_demo d
on conflict (id) do nothing;

-- Identities required for GoTrue email login.
delete from auth.identities
where user_id in (select id from _fv_demo);

insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  d.id,
  d.id,
  jsonb_build_object(
    'sub', d.id::text,
    'email', d.email,
    'email_verified', true
  ),
  'email',
  d.id::text,
  now(),
  now(),
  now()
from _fv_demo d;

-- Enrich profiles.
update public.profiles p
set
  display_name = d.display_name,
  username = d.username,
  bio = d.bio,
  city = d.city,
  state = d.state,
  account_type = d.account_type,
  is_private = false,
  profile_visibility = 'public',
  is_demo = true,
  terms_accepted_at = coalesce(p.terms_accepted_at, now()),
  privacy_accepted_at = coalesce(p.privacy_accepted_at, now()),
  updated_at = now()
from _fv_demo d
where p.id = d.id;

-- Organizers for event hosts.
insert into public.community_organizers (profile_id)
select d.id from _fv_demo d where d.n in (12, 13, 14, 20, 21, 25)
on conflict (profile_id) do nothing;


-- Profile media (external picsum URLs) for Explore + VUE.
insert into public.profile_media (
  id, profile_id, storage_path, storage_provider, media_type,
  featured_for_trending, sort_order, media_role
)
select
  ('b1000000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
  d.id,
  'https://picsum.photos/seed/fvdemo_av_' || d.n::text || '/800/800',
  'external',
  'image',
  true,
  0,
  'avatar'
from _fv_demo d
on conflict (storage_path) do nothing;

insert into public.profile_media (
  id, profile_id, storage_path, storage_provider, media_type,
  featured_for_trending, sort_order, media_role
)
select
  ('b2000000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
  d.id,
  'https://picsum.photos/seed/fvdemo_gal_' || d.n::text || '/900/1200',
  'external',
  'image',
  (d.n % 3 = 0),
  1,
  'gallery'
from _fv_demo d
on conflict (storage_path) do nothing;


-- Feed / VUE posts
insert into public.community_news_posts (
  id, author_id, body, status, visibility, publish_destination,
  author_profile_type, is_demo, created_at
)
select
  ('c1000000-0000-4000-8000-' || lpad((d.n)::text, 12, '0'))::uuid,
  d.id,
  case (d.n % 5)
    when 0 then 'FirstVue demo: weekend glow-up from ' || d.display_name || '.'
    when 1 then 'Behind the chair with ' || d.display_name || ' — ATL energy.'
    when 2 then 'New work dropping soon. Follow @' || d.username || ' for updates.'
    when 3 then 'Community love from ' || d.city || '. Come through.'
    else 'Soft launch vibes on FirstVue. This profile is demo data.'
  end,
  'approved',
  'public',
  case when d.n % 2 = 0 then 'feed_and_vue' else 'feed' end,
  'user',
  true,
  now() - ((26 - d.n) || ' hours')::interval
from _fv_demo d;

insert into public.community_news_posts (
  id, author_id, body, status, visibility, publish_destination,
  author_profile_type, is_demo, created_at
)
select
  ('c2000000-0000-4000-8000-' || lpad((d.n)::text, 12, '0'))::uuid,
  d.id,
  'VUE featured look from ' || d.display_name || '. (Demo content — safe to delete.)',
  'approved',
  'public',
  'vue',
  'user',
  true,
  now() - ((d.n) || ' hours')::interval
from _fv_demo d
where d.n <= 18;

insert into public.community_news_post_media (
  id, post_id, storage_path, storage_provider, media_type, sort_order
)
select
  ('d1000000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
  ('c1000000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
  'https://picsum.photos/seed/fvdemo_post_' || d.n::text || '/1000/1250',
  'external',
  'image',
  0
from _fv_demo d
on conflict (storage_path) do nothing;

insert into public.community_news_post_media (
  id, post_id, storage_path, storage_provider, media_type, sort_order
)
select
  ('d2000000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
  ('c2000000-0000-4000-8000-' || lpad(d.n::text, 12, '0'))::uuid,
  'https://picsum.photos/seed/fvdemo_vue_' || d.n::text || '/900/1400',
  'external',
  'image',
  0
from _fv_demo d
where d.n <= 18
on conflict (storage_path) do nothing;


-- Demo businesses (5)
insert into public.businesses (
  id, name, description, status, verification_status, business_type,
  created_by, services, popularity_score, demand_score, average_rating,
  is_demo, accepts_bookings
) values
  ('e1000000-0000-4000-8000-000000000001'::uuid,
   '[DEMO] Soft Lumen Studio', 'Demo salon for FirstVue discovery.', 'approved', 'verified',
   'salon', 'a0000000-0000-4000-8000-000000000001'::uuid,
   array['cuts','color','blowouts'], 82, 71, 4.8, true, true),
  ('e1000000-0000-4000-8000-000000000002'::uuid,
   '[DEMO] Midtown Fade Room', 'Demo barbershop listing.', 'approved', 'verified',
   'barbershop', 'a0000000-0000-4000-8000-000000000002'::uuid,
   array['fades','beards','lineups'], 76, 68, 4.7, true, true),
  ('e1000000-0000-4000-8000-000000000012'::uuid,
   '[DEMO] Harper Atelier', 'Demo boutique / retail.', 'approved', 'unverified',
   'boutique', 'a0000000-0000-4000-8000-000000000012'::uuid,
   array['styling','personal shopping'], 64, 55, 4.6, true, false),
  ('e1000000-0000-4000-8000-000000000020'::uuid,
   '[DEMO] Eastside Roast', 'Demo coffee shop.', 'approved', 'verified',
   'cafe', 'a0000000-0000-4000-8000-000000000020'::uuid,
   array['espresso','pour over'], 70, 60, 4.9, true, false),
  ('e1000000-0000-4000-8000-000000000021'::uuid,
   '[DEMO] Quiet Hour Spa', 'Demo spa and recovery lounge.', 'approved', 'verified',
   'spa', 'a0000000-0000-4000-8000-000000000021'::uuid,
   array['facials','massage'], 88, 74, 4.9, true, true)
on conflict (id) do nothing;

insert into public.business_locations (
  business_id, address_line_1, city, state, postal_code, country_code, latitude, longitude
) values
  ('e1000000-0000-4000-8000-000000000001'::uuid, '120 Peachtree St', 'Atlanta', 'GA', '30303', 'US', 33.7550, -84.3900),
  ('e1000000-0000-4000-8000-000000000002'::uuid, '900 Juniper St', 'Atlanta', 'GA', '30309', 'US', 33.7810, -84.3830),
  ('e1000000-0000-4000-8000-000000000012'::uuid, '3500 Peachtree Rd', 'Atlanta', 'GA', '30326', 'US', 33.8467, -84.3622),
  ('e1000000-0000-4000-8000-000000000020'::uuid, '215 Church St', 'Decatur', 'GA', '30030', 'US', 33.7748, -84.2963),
  ('e1000000-0000-4000-8000-000000000021'::uuid, '44 Irby Ave', 'Atlanta', 'GA', '30305', 'US', 33.8400, -84.3800);

insert into public.business_memberships (business_id, profile_id, role) values
  ('e1000000-0000-4000-8000-000000000001'::uuid, 'a0000000-0000-4000-8000-000000000001'::uuid, 'owner'),
  ('e1000000-0000-4000-8000-000000000002'::uuid, 'a0000000-0000-4000-8000-000000000002'::uuid, 'owner'),
  ('e1000000-0000-4000-8000-000000000012'::uuid, 'a0000000-0000-4000-8000-000000000012'::uuid, 'owner'),
  ('e1000000-0000-4000-8000-000000000020'::uuid, 'a0000000-0000-4000-8000-000000000020'::uuid, 'owner'),
  ('e1000000-0000-4000-8000-000000000021'::uuid, 'a0000000-0000-4000-8000-000000000021'::uuid, 'owner')
on conflict do nothing;

insert into public.business_media (
  id, business_id, storage_path, storage_provider, media_type, caption,
  featured_for_trending, sort_order
) values
  ('f1000000-0000-4000-8000-000000000001'::uuid, 'e1000000-0000-4000-8000-000000000001'::uuid,
   'https://picsum.photos/seed/fvdemo_biz_1/1000/1200', 'external', 'image',
   'Soft Lumen suite', true, 0),
  ('f1000000-0000-4000-8000-000000000002'::uuid, 'e1000000-0000-4000-8000-000000000002'::uuid,
   'https://picsum.photos/seed/fvdemo_biz_2/1000/1200', 'external', 'image',
   'Fade Room chair', true, 0),
  ('f1000000-0000-4000-8000-000000000012'::uuid, 'e1000000-0000-4000-8000-000000000012'::uuid,
   'https://picsum.photos/seed/fvdemo_biz_12/1000/1200', 'external', 'image',
   'Atelier rack', true, 0),
  ('f1000000-0000-4000-8000-000000000020'::uuid, 'e1000000-0000-4000-8000-000000000020'::uuid,
   'https://picsum.photos/seed/fvdemo_biz_20/1000/1200', 'external', 'image',
   'Roastery counter', true, 0),
  ('f1000000-0000-4000-8000-000000000021'::uuid, 'e1000000-0000-4000-8000-000000000021'::uuid,
   'https://picsum.photos/seed/fvdemo_biz_21/1000/1200', 'external', 'image',
   'Quiet Hour treatment room', true, 0)
on conflict (storage_path) do nothing;


-- Demo events (3)
insert into public.community_events (
  id, organizer_id, business_id, title, description, event_at,
  location_label, status, is_demo,
  cover_storage_path, cover_storage_provider
) values
  ('aa000000-0000-4000-8000-000000000001'::uuid,
   'a0000000-0000-4000-8000-000000000014'::uuid,
   'e1000000-0000-4000-8000-000000000001'::uuid,
   '[DEMO] Soft Glam Night Market',
   'Demo event — makers, beauty pop-ups, and live styling.',
   now() + interval '3 days',
   'Midtown Atlanta',
   'approved', true,
   'https://picsum.photos/seed/fvdemo_event_1/1200/800', 'external'),
  ('aa000000-0000-4000-8000-000000000002'::uuid,
   'a0000000-0000-4000-8000-000000000013'::uuid,
   'e1000000-0000-4000-8000-000000000020'::uuid,
   '[DEMO] Chef Table Pop-Up',
   'Demo tasting menu night hosted on FirstVue.',
   now() + interval '6 days',
   'Decatur Square',
   'approved', true,
   'https://picsum.photos/seed/fvdemo_event_2/1200/800', 'external'),
  ('aa000000-0000-4000-8000-000000000003'::uuid,
   'a0000000-0000-4000-8000-000000000025'::uuid,
   null,
   '[DEMO] Maker Meetup',
   'Demo community meetup for creatives and founders.',
   now() + interval '10 days',
   'Old Fourth Ward',
   'approved', true,
   'https://picsum.photos/seed/fvdemo_event_3/1200/800', 'external')
on conflict (id) do nothing;

commit;

-- Quick verification
select
  (select count(*) from public.profiles where is_demo) as demo_people,
  (select count(*) from public.community_news_posts where is_demo) as demo_posts,
  (select count(*) from public.businesses where is_demo) as demo_businesses,
  (select count(*) from public.community_events where is_demo) as demo_events;

