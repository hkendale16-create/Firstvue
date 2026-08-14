-- =============================================================================
-- FirstVue Phases 5–6 — Story storage expiry, rental public/private location,
-- feed/discovery indexes.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Expired stories must not remain readable via Storage
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from storage.buckets where id = 'stories'
  ) then
    drop policy if exists "Public read unexpired story objects" on storage.objects;
    create policy "Public read unexpired story objects"
      on storage.objects for select
      to anon, authenticated
      using (
        bucket_id = 'stories'
        and exists (
          select 1
          from public.stories s
          where s.media_path = name
            and s.expires_at > now()
        )
      );

    drop policy if exists "Owners write own story objects" on storage.objects;
    create policy "Owners write own story objects"
      on storage.objects for insert
      to authenticated
      with check (
        bucket_id = 'stories'
        and split_part(name, '/', 1) = auth.uid()::text
      );

    drop policy if exists "Owners delete own story objects" on storage.objects;
    create policy "Owners delete own story objects"
      on storage.objects for delete
      to authenticated
      using (
        bucket_id = 'stories'
        and split_part(name, '/', 1) = auth.uid()::text
      );
  end if;
exception
  when undefined_table then null;
  when insufficient_privilege then null;
end $$;

-- ---------------------------------------------------------------------------
-- B) Rental public vs private location
--     Exact street / coordinates / place_id live on an owner-only table so
--     existing approved-rental SELECT policies cannot leak them.
-- ---------------------------------------------------------------------------
alter table public.rentals
  add column if not exists country_code text not null default 'US',
  add column if not exists metro_area text,
  add column if not exists show_exact_address boolean not null default false,
  add column if not exists public_area text,
  add column if not exists public_street text,
  add column if not exists pricing_mode text not null default 'exact'
    check (pricing_mode in ('exact', 'starting_at', 'free', 'contact')),
  add column if not exists billing_period text default 'month';

create index if not exists rentals_city_metro_idx
  on public.rentals (lower(city), lower(coalesce(metro_area, '')))
  where status = 'approved';

create table if not exists public.rental_private_locations (
  rental_id uuid primary key references public.rentals(id) on delete cascade,
  address_line_1 text,
  address_line_2 text,
  city text,
  state text,
  postal_code text,
  country_code text not null default 'US',
  formatted_address text,
  place_id text,
  latitude double precision,
  longitude double precision,
  updated_at timestamptz not null default now()
);

alter table public.rental_private_locations enable row level security;

drop policy if exists "Owners manage rental private locations" on public.rental_private_locations;
create policy "Owners manage rental private locations"
  on public.rental_private_locations for all
  to authenticated
  using (
    exists (
      select 1 from public.rentals r
      where r.id = rental_id
        and (r.owner_id = auth.uid() or public.is_firstvue_admin())
    )
  )
  with check (
    exists (
      select 1 from public.rentals r
      where r.id = rental_id
        and (r.owner_id = auth.uid() or public.is_firstvue_admin())
    )
  );

-- Public listings: city/metro always; street only when the owner opted in.
-- Never select from rental_private_locations here.
create or replace view public.rental_public_listings
with (security_invoker = true) as
select
  r.id,
  r.owner_id,
  r.business_id,
  r.title,
  r.description,
  r.city,
  r.state,
  r.postal_code,
  r.country_code,
  r.metro_area,
  r.public_area,
  case when r.show_exact_address then r.public_street else null end as public_street,
  r.weekly_price_cents,
  r.monthly_price_cents,
  r.pricing_mode,
  r.billing_period,
  r.deposit_cents,
  r.property_type,
  r.bedrooms,
  r.bathrooms,
  r.square_footage,
  r.pet_policy,
  r.lease_length,
  r.status,
  r.audience,
  r.show_exact_address,
  r.created_at
from public.rentals r
where r.status = 'approved';

grant select on public.rental_public_listings to anon, authenticated;

drop policy if exists "Authenticated users view approved rentals" on public.rentals;
drop policy if exists "Public view approved rentals" on public.rentals;
create policy "Public view approved rentals"
  on public.rentals for select
  to anon, authenticated
  using (status = 'approved' or owner_id = auth.uid() or public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- C) Feed / VUE indexes for cursor pagination
-- ---------------------------------------------------------------------------
create index if not exists community_news_posts_created_idx
  on public.community_news_posts (created_at desc)
  where status = 'approved';

create index if not exists business_media_created_idx
  on public.business_media (created_at desc);

create index if not exists profile_media_created_idx
  on public.profile_media (created_at desc);
