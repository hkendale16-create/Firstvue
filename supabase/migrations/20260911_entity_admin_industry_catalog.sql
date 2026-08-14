-- =============================================================================
-- FirstVue Phase 2 — industry catalog, entity team roles, catalogs/inventory,
-- customers, pricing modes, New-label helper, follow-suggestion dismissals.
-- Additive. Does not rewrite production rows.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Industry catalog: stable slugs + template keys (not display text)
-- ---------------------------------------------------------------------------
alter table public.industries
  add column if not exists template_key text,
  add column if not exists parent_slug text,
  add column if not exists sort_order integer not null default 100;

create unique index if not exists industries_slug_uidx
  on public.industries (slug);

insert into public.industries (name, slug, template_key, parent_slug, sort_order, is_active)
values
  ('Beauty & Grooming', 'beauty-grooming', 'beauty', null, 10, true),
  ('Barbershop', 'barbershop', 'beauty', 'beauty-grooming', 11, true),
  ('Salon', 'salon', 'beauty', 'beauty-grooming', 12, true),
  ('Spa', 'spa', 'beauty', 'beauty-grooming', 13, true),
  ('Nail Salon', 'nail-salon', 'beauty', 'beauty-grooming', 14, true),
  ('Food & Dining', 'food-dining', 'food', null, 20, true),
  ('Restaurant', 'restaurant', 'food', 'food-dining', 21, true),
  ('Cafe', 'cafe', 'food', 'food-dining', 22, true),
  ('Bakery', 'bakery', 'food', 'food-dining', 23, true),
  ('Nightlife', 'nightlife', 'nightlife', null, 30, true),
  ('Bar', 'bar', 'nightlife', 'nightlife', 31, true),
  ('Lounge', 'lounge', 'nightlife', 'nightlife', 32, true),
  ('Events', 'events', 'event', null, 40, true),
  ('Event Organizer', 'event-organizer', 'event', 'events', 41, true),
  ('Rentals', 'rentals', 'rental', null, 50, true),
  ('Activities', 'activities', 'activity', null, 60, true),
  ('Activity Provider', 'activity-provider', 'activity', 'activities', 61, true),
  ('Professional Services', 'professional-services', 'professional', null, 70, true),
  ('Retail', 'retail', 'retail', null, 80, true),
  ('Community', 'community', 'community', null, 90, true),
  ('Group', 'group', 'community', 'community', 91, true),
  ('General Business', 'general-business', 'general', null, 200, true)
on conflict (slug) do update
  set template_key = excluded.template_key,
      parent_slug = excluded.parent_slug,
      name = excluded.name,
      sort_order = excluded.sort_order,
      is_active = true;

-- Categories remain child records; backfill from industries when missing.
insert into public.categories (industry_id, name, slug, is_active)
select i.id, i.name, i.slug, true
from public.industries i
where not exists (
  select 1 from public.categories c where c.slug = i.slug
)
on conflict (slug) do nothing;

alter table public.businesses
  add column if not exists primary_industry_id uuid references public.industries(id),
  add column if not exists secondary_industry_ids uuid[] not null default '{}';

create index if not exists businesses_primary_industry_idx
  on public.businesses (primary_industry_id)
  where primary_industry_id is not null;

-- Map existing business_type display text onto industry slugs without deleting data.
update public.businesses b
set primary_industry_id = i.id
from public.industries i
where b.primary_industry_id is null
  and i.slug = case
    when lower(coalesce(b.business_type, '')) like '%barber%' then 'barbershop'
    when lower(coalesce(b.business_type, '')) like '%salon%' then 'salon'
    when lower(coalesce(b.business_type, '')) like '%spa%'
      or lower(coalesce(b.business_type, '')) like '%nail%' then 'spa'
    when lower(coalesce(b.business_type, '')) like '%restaurant%'
      or lower(coalesce(b.business_type, '')) like '%dining%'
      or lower(coalesce(b.business_type, '')) like '%food%' then 'restaurant'
    when lower(coalesce(b.business_type, '')) like '%cafe%'
      or lower(coalesce(b.business_type, '')) like '%bakery%' then 'cafe'
    when lower(coalesce(b.business_type, '')) like '%bar%'
      or lower(coalesce(b.business_type, '')) like '%lounge%'
      or lower(coalesce(b.business_type, '')) like '%nightlife%' then 'bar'
    when lower(coalesce(b.business_type, '')) like '%event%' then 'event-organizer'
    when lower(coalesce(b.business_type, '')) like '%rental%' then 'rentals'
    when lower(coalesce(b.business_type, '')) like '%activit%' then 'activity-provider'
    else 'general-business'
  end;

-- ---------------------------------------------------------------------------
-- B) Entity team roles: Owner / Manager / Content editor / Moderator /
--    Analytics viewer. Keep legacy 'staff' as a content-editor alias.
-- ---------------------------------------------------------------------------
do $$
begin
  alter table public.business_memberships
    drop constraint if exists business_memberships_role_check;
exception
  when undefined_object then null;
end $$;

alter table public.business_memberships
  add constraint business_memberships_role_check
  check (role in (
    'owner',
    'manager',
    'staff',
    'content_editor',
    'moderator',
    'analytics_viewer'
  ));

create or replace function public.has_business_role(
  p_business_id uuid,
  p_roles text[],
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_profile_id is not null
    and (
      exists (
        select 1 from public.businesses b
        where b.id = p_business_id
          and b.created_by = p_profile_id
          and ('owner' = any (p_roles) or 'manager' = any (p_roles))
      )
      or exists (
        select 1 from public.business_memberships m
        where m.business_id = p_business_id
          and m.profile_id = p_profile_id
          and (
            m.role = any (p_roles)
            or (m.role = 'staff' and 'content_editor' = any (p_roles))
            or (m.role = 'owner' and (
              'manager' = any (p_roles)
              or 'content_editor' = any (p_roles)
              or 'moderator' = any (p_roles)
              or 'analytics_viewer' = any (p_roles)
            ))
            or (m.role = 'manager' and (
              'content_editor' = any (p_roles)
              or 'moderator' = any (p_roles)
              or 'analytics_viewer' = any (p_roles)
            ))
          )
      )
    ),
    false
  );
$$;

revoke all on function public.has_business_role(uuid, text[], uuid) from public;
grant execute on function public.has_business_role(uuid, text[], uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- C) Pricing modes on existing catalog tables (Exact / Starting at / Free /
--    Contact). Existing price columns are preserved.
-- ---------------------------------------------------------------------------
alter table public.business_services
  add column if not exists pricing_mode text not null default 'exact'
    check (pricing_mode in ('exact', 'starting_at', 'free', 'contact')),
  add column if not exists quantity integer,
  add column if not exists sku text,
  add column if not exists low_stock_threshold integer;

alter table public.business_menu_items
  add column if not exists pricing_mode text not null default 'exact'
    check (pricing_mode in ('exact', 'starting_at', 'free', 'contact')),
  add column if not exists price_cents integer,
  add column if not exists quantity integer,
  add column if not exists sku text;

alter table public.professional_catalog_items
  add column if not exists pricing_mode text not null default 'exact'
    check (pricing_mode in ('exact', 'starting_at', 'free', 'contact')),
  add column if not exists quantity integer,
  add column if not exists sku text;

-- ---------------------------------------------------------------------------
-- D) Private customers + inventory (entity-scoped, RLS)
-- ---------------------------------------------------------------------------
create table if not exists public.entity_customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  display_name text not null,
  email text,
  phone text,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists entity_customers_business_idx
  on public.entity_customers (business_id, created_at desc);

alter table public.entity_customers enable row level security;

drop policy if exists "Entity roles read customers" on public.entity_customers;
create policy "Entity roles read customers"
  on public.entity_customers for select
  to authenticated
  using (
    public.has_business_role(
      business_id,
      array['owner', 'manager', 'content_editor', 'analytics_viewer']
    )
  );

drop policy if exists "Entity managers write customers" on public.entity_customers;
create policy "Entity managers write customers"
  on public.entity_customers for all
  to authenticated
  using (
    public.has_business_role(business_id, array['owner', 'manager', 'content_editor'])
  )
  with check (
    public.has_business_role(business_id, array['owner', 'manager', 'content_editor'])
  );

create table if not exists public.entity_inventory_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  sku text,
  quantity integer not null default 0,
  low_stock_threshold integer not null default 0,
  pricing_mode text not null default 'exact'
    check (pricing_mode in ('exact', 'starting_at', 'free', 'contact')),
  price_cents integer,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists entity_inventory_business_idx
  on public.entity_inventory_items (business_id, name);

alter table public.entity_inventory_items enable row level security;

drop policy if exists "Public reads available inventory names" on public.entity_inventory_items;

drop policy if exists "Entity roles manage inventory" on public.entity_inventory_items;
create policy "Entity roles manage inventory"
  on public.entity_inventory_items for all
  to authenticated
  using (
    public.has_business_role(business_id, array['owner', 'manager', 'content_editor'])
  )
  with check (
    public.has_business_role(business_id, array['owner', 'manager', 'content_editor'])
  );

-- ---------------------------------------------------------------------------
-- E) New label helper — computed from created_at, never a stale boolean
-- ---------------------------------------------------------------------------
create or replace function public.is_new_profile(p_created_at timestamptz)
returns boolean
language sql
immutable
as $$
  select coalesce(p_created_at >= (now() - interval '10 days'), false);
$$;

revoke all on function public.is_new_profile(timestamptz) from public;
grant execute on function public.is_new_profile(timestamptz) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- F) Consider Following dismissals (per-user persistence)
-- ---------------------------------------------------------------------------
create table if not exists public.dismissed_follow_suggestions (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null,
  target_type text not null default 'business',
  dismissed_at timestamptz not null default now(),
  primary key (profile_id, target_id, target_type)
);

alter table public.dismissed_follow_suggestions enable row level security;

drop policy if exists "Users manage own follow dismissals" on public.dismissed_follow_suggestions;
create policy "Users manage own follow dismissals"
  on public.dismissed_follow_suggestions for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
