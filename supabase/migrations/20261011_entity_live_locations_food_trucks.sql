-- =============================================================================
-- FirstVue: reusable Live Locations + Food Trucks discovery foundation
-- Extends business_open_sessions (do not hardcode to food trucks only).
-- No ordering / checkout / customer payments.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Industry: Food Truck (catalog identity)
-- ---------------------------------------------------------------------------

insert into public.industries (name, slug, template_key, parent_slug, sort_order, is_active)
values ('Food Truck', 'food-truck', 'food', 'food-dining', 24, true)
on conflict (slug) do update
  set name = excluded.name,
      template_key = excluded.template_key,
      parent_slug = excluded.parent_slug,
      sort_order = excluded.sort_order,
      is_active = true;

-- Prefer food-truck over generic restaurant when business_type mentions truck.
update public.businesses b
set primary_industry_id = i.id
from public.industries i
where i.slug = 'food-truck'
  and b.primary_industry_id is distinct from i.id
  and (
    lower(coalesce(b.business_type, '')) like '%food truck%'
    or lower(coalesce(b.business_type, '')) like '%foodtruck%'
  );

-- ---------------------------------------------------------------------------
-- Enhance open sessions → reusable live locations
-- ---------------------------------------------------------------------------

alter table public.business_open_sessions
  add column if not exists location_type text not null default 'mobile_business'
    check (location_type in (
      'food_truck',
      'mobile_coffee',
      'popup_vendor',
      'mobile_barber',
      'artist',
      'market',
      'mobile_service',
      'mobile_business',
      'other'
    ));

alter table public.business_open_sessions
  add column if not exists status text not null default 'active'
    check (status in ('active', 'ended', 'expired'));

alter table public.business_open_sessions
  add column if not exists place_label text;

alter table public.business_open_sessions
  add column if not exists address_text text;

alter table public.business_open_sessions
  add column if not exists event_id uuid references public.community_events(id) on delete set null;

-- Backfill food_truck type where business_type indicates a truck.
update public.business_open_sessions s
set location_type = 'food_truck'
from public.businesses b
where b.id = s.business_id
  and s.location_type = 'mobile_business'
  and (
    lower(coalesce(b.business_type, '')) like '%food truck%'
    or lower(coalesce(b.business_type, '')) like '%foodtruck%'
  );

-- Mark already-ended rows.
update public.business_open_sessions
set status = 'expired'
where ends_at <= now()
  and status = 'active';

create index if not exists business_open_sessions_active_geo_idx
  on public.business_open_sessions (status, ends_at, latitude, longitude)
  where status = 'active';

create index if not exists business_open_sessions_location_type_idx
  on public.business_open_sessions (location_type, status, ends_at desc);

-- At most one active live location per business.
create unique index if not exists business_open_sessions_one_active_uidx
  on public.business_open_sessions (business_id)
  where status = 'active' and ends_at > now();

-- ---------------------------------------------------------------------------
-- Scheduled stops (distinct from LIVE NOW)
-- ---------------------------------------------------------------------------

create table if not exists public.business_scheduled_stops (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete restrict,
  stop_date date not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  place_label text,
  address_text text,
  latitude double precision,
  longitude double precision,
  event_id uuid references public.community_events(id) on delete set null,
  note text,
  status text not null default 'scheduled' check (
    status in ('scheduled', 'cancelled', 'completed')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_scheduled_stops_window check (ends_at > starts_at)
);

create index if not exists business_scheduled_stops_business_starts_idx
  on public.business_scheduled_stops (business_id, starts_at);

create index if not exists business_scheduled_stops_day_idx
  on public.business_scheduled_stops (stop_date, status, starts_at);

alter table public.business_scheduled_stops enable row level security;

drop policy if exists "Public reads scheduled stops" on public.business_scheduled_stops;
create policy "Public reads scheduled stops"
  on public.business_scheduled_stops for select to anon, authenticated
  using (
    status = 'scheduled'
    and exists (
      select 1 from public.businesses b
      where b.id = business_id and b.status = 'approved'
    )
  );

drop policy if exists "Owners manage scheduled stops" on public.business_scheduled_stops;
create policy "Owners manage scheduled stops"
  on public.business_scheduled_stops for all to authenticated
  using (
    public.has_business_role(business_id, array['owner', 'manager']::text[], auth.uid())
    or public.is_firstvue_admin()
  )
  with check (
    created_by = auth.uid()
    and public.has_business_role(business_id, array['owner', 'manager']::text[], auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Founding / launch badges (admin-controlled, not purchasable)
-- ---------------------------------------------------------------------------

create table if not exists public.business_launch_badges (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  badge_key text not null check (
    badge_key in ('founding_food_truck', 'founding_member', 'launch_partner')
  ),
  market_label text not null default 'Atlanta',
  year_label integer not null default 2026,
  awarded_at timestamptz not null default now(),
  awarded_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  unique (business_id, badge_key)
);

create index if not exists business_launch_badges_active_idx
  on public.business_launch_badges (badge_key, business_id)
  where revoked_at is null;

alter table public.business_launch_badges enable row level security;

drop policy if exists "Public reads active launch badges" on public.business_launch_badges;
create policy "Public reads active launch badges"
  on public.business_launch_badges for select to anon, authenticated
  using (
    revoked_at is null
    and exists (
      select 1 from public.businesses b
      where b.id = business_id
        and b.status = 'approved'
        and coalesce(b.is_demo, false) = false
    )
  );

drop policy if exists "Admins manage launch badges" on public.business_launch_badges;
create policy "Admins manage launch badges"
  on public.business_launch_badges for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- Discovery analytics (append-only; exclude demo from owner dashboards)
-- ---------------------------------------------------------------------------

create table if not exists public.business_discovery_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  event_name text not null check (
    event_name in (
      'food_truck_profile_viewed',
      'food_truck_live_viewed',
      'food_truck_menu_viewed',
      'food_truck_directions_tapped',
      'food_truck_followed',
      'food_truck_shared',
      'live_location_started',
      'live_location_extended',
      'live_location_ended',
      'scheduled_stop_viewed',
      'vue_opened_from_food_truck',
      'event_opened_from_food_truck'
    )
  ),
  session_id uuid,
  stop_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists business_discovery_events_business_created_idx
  on public.business_discovery_events (business_id, created_at desc);

create index if not exists business_discovery_events_name_idx
  on public.business_discovery_events (event_name, created_at desc);

alter table public.business_discovery_events enable row level security;

drop policy if exists "Users insert own discovery events" on public.business_discovery_events;
create policy "Users insert own discovery events"
  on public.business_discovery_events for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Owners read discovery events" on public.business_discovery_events;
create policy "Owners read discovery events"
  on public.business_discovery_events for select to authenticated
  using (
    profile_id = auth.uid()
    or public.has_business_role(business_id, array['owner', 'manager', 'analytics_viewer']::text[], auth.uid())
    or public.is_firstvue_admin()
  );

-- ---------------------------------------------------------------------------
-- Notification preference: live nearby
-- ---------------------------------------------------------------------------

alter table public.user_preferences
  add column if not exists push_live_nearby boolean not null default true;

alter table public.user_preferences
  add column if not exists live_nearby_notify_radius_miles double precision
    not null default 5
    check (live_nearby_notify_radius_miles > 0 and live_nearby_notify_radius_miles <= 50);

-- Cooldown log to avoid spam
create table if not exists public.live_nearby_notify_log (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  session_id uuid not null,
  notified_at timestamptz not null default now(),
  unique (profile_id, session_id)
);

create index if not exists live_nearby_notify_log_cooldown_idx
  on public.live_nearby_notify_log (profile_id, business_id, notified_at desc);

alter table public.live_nearby_notify_log enable row level security;

drop policy if exists "Users read own live notify log" on public.live_nearby_notify_log;
create policy "Users read own live notify log"
  on public.live_nearby_notify_log for select to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- Future promo stubs (disabled; no real payments)
-- ---------------------------------------------------------------------------

create table if not exists public.mobile_business_promotions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_key text not null check (
    product_key in ('boost_my_truck', 'lunch_rush', 'featured_nearby')
  ),
  status text not null default 'draft' check (
    status in ('draft', 'scheduled', 'active', 'ended', 'cancelled')
  ),
  starts_at timestamptz,
  ends_at timestamptz,
  label text not null default 'Promoted',
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

alter table public.mobile_business_promotions enable row level security;

drop policy if exists "Public reads active mobile promotions" on public.mobile_business_promotions;
create policy "Public reads active mobile promotions"
  on public.mobile_business_promotions for select to anon, authenticated
  using (
    status = 'active'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at > now())
  );

-- No client write policies — future payment-gated server writes only.

-- ---------------------------------------------------------------------------
-- RPCs: start / extend / end / nearby / expire / notify
-- ---------------------------------------------------------------------------

create or replace function public.fv_infer_live_location_type(p_business_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when lower(coalesce(b.business_type, '')) like '%food truck%'
      or lower(coalesce(b.business_type, '')) like '%foodtruck%'
      or exists (
        select 1 from public.industries i
        where i.id = b.primary_industry_id and i.slug = 'food-truck'
      )
      then 'food_truck'
    when lower(coalesce(b.business_type, '')) like '%coffee%'
      and lower(coalesce(b.business_type, '')) like '%mobile%'
      then 'mobile_coffee'
    when lower(coalesce(b.business_type, '')) like '%popup%'
      or lower(coalesce(b.business_type, '')) like '%pop-up%'
      then 'popup_vendor'
    when lower(coalesce(b.business_type, '')) like '%barber%'
      and lower(coalesce(b.business_type, '')) like '%mobile%'
      then 'mobile_barber'
    else 'mobile_business'
  end
  from public.businesses b
  where b.id = p_business_id;
$$;

create or replace function public.start_business_open_session(
  p_business_id uuid,
  p_hours double precision default 4,
  p_note text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.business_open_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hours double precision := greatest(0.5, least(coalesce(p_hours, 4), 12));
  v_row public.business_open_sessions;
  v_type text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_business_id is null then
    raise exception 'business_id required';
  end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then
    raise exception 'Not allowed';
  end if;
  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.status = 'approved'
  ) then
    raise exception 'Business not available';
  end if;

  v_type := coalesce(public.fv_infer_live_location_type(p_business_id), 'mobile_business');

  update public.business_open_sessions
  set ends_at = least(ends_at, now()),
      status = 'ended',
      updated_at = now()
  where business_id = p_business_id
    and status = 'active'
    and ends_at > now();

  insert into public.business_open_sessions (
    business_id, opened_by, note, latitude, longitude,
    started_at, ends_at, location_type, status
  ) values (
    p_business_id,
    v_uid,
    nullif(trim(coalesce(p_note, '')), ''),
    p_latitude,
    p_longitude,
    now(),
    now() + make_interval(secs => (v_hours * 3600)::int),
    v_type,
    'active'
  )
  returning * into v_row;

  insert into public.business_discovery_events (
    business_id, profile_id, event_name, session_id, metadata
  ) values (
    p_business_id, v_uid, 'live_location_started', v_row.id,
    jsonb_build_object('hours', v_hours, 'location_type', v_type)
  );

  perform public.fv_notify_followers_live_nearby(v_row.id);

  return v_row;
end;
$$;

create or replace function public.start_business_live_location(
  p_business_id uuid,
  p_hours double precision default 4,
  p_note text default null,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_place_label text default null,
  p_address_text text default null,
  p_event_id uuid default null,
  p_location_type text default null
)
returns public.business_open_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hours double precision := greatest(0.5, least(coalesce(p_hours, 4), 12));
  v_row public.business_open_sessions;
  v_type text;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then
    raise exception 'Not allowed';
  end if;
  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.status = 'approved'
  ) then
    raise exception 'Business not available';
  end if;

  v_type := coalesce(
    nullif(trim(coalesce(p_location_type, '')), ''),
    public.fv_infer_live_location_type(p_business_id),
    'mobile_business'
  );

  update public.business_open_sessions
  set ends_at = least(ends_at, now()),
      status = 'ended',
      updated_at = now()
  where business_id = p_business_id
    and status = 'active'
    and ends_at > now();

  insert into public.business_open_sessions (
    business_id, opened_by, note, latitude, longitude,
    started_at, ends_at, location_type, status, place_label, address_text, event_id
  ) values (
    p_business_id, v_uid,
    nullif(trim(coalesce(p_note, '')), ''),
    p_latitude, p_longitude,
    now(),
    now() + make_interval(secs => (v_hours * 3600)::int),
    v_type, 'active',
    nullif(trim(coalesce(p_place_label, '')), ''),
    nullif(trim(coalesce(p_address_text, '')), ''),
    p_event_id
  )
  returning * into v_row;

  insert into public.business_discovery_events (
    business_id, profile_id, event_name, session_id, metadata
  ) values (
    p_business_id, v_uid, 'live_location_started', v_row.id,
    jsonb_build_object('hours', v_hours, 'location_type', v_type)
  );

  perform public.fv_notify_followers_live_nearby(v_row.id);
  return v_row;
end;
$$;

revoke all on function public.start_business_live_location(
  uuid, double precision, text, double precision, double precision, text, text, uuid, text
) from public;
grant execute on function public.start_business_live_location(
  uuid, double precision, text, double precision, double precision, text, text, uuid, text
) to authenticated;

create or replace function public.extend_business_open_session(
  p_business_id uuid,
  p_additional_hours double precision default 1
)
returns public.business_open_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hours double precision := greatest(0.25, least(coalesce(p_additional_hours, 1), 8));
  v_row public.business_open_sessions;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then
    raise exception 'Not allowed';
  end if;

  update public.business_open_sessions
  set ends_at = least(
        started_at + interval '12 hours',
        ends_at + make_interval(secs => (v_hours * 3600)::int)
      ),
      updated_at = now()
  where business_id = p_business_id
    and status = 'active'
    and ends_at > now()
  returning * into v_row;

  if v_row.id is null then
    raise exception 'No active live location';
  end if;

  insert into public.business_discovery_events (
    business_id, profile_id, event_name, session_id, metadata
  ) values (
    p_business_id, v_uid, 'live_location_extended', v_row.id,
    jsonb_build_object('additional_hours', v_hours)
  );

  return v_row;
end;
$$;

revoke all on function public.extend_business_open_session(uuid, double precision) from public;
grant execute on function public.extend_business_open_session(uuid, double precision) to authenticated;

create or replace function public.end_business_open_session(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_session_id uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then
    raise exception 'Not allowed';
  end if;

  update public.business_open_sessions
  set ends_at = now(),
      status = 'ended',
      updated_at = now()
  where business_id = p_business_id
    and status = 'active'
    and ends_at > now()
  returning id into v_session_id;

  if v_session_id is not null then
    insert into public.business_discovery_events (
      business_id, profile_id, event_name, session_id
    ) values (
      p_business_id, v_uid, 'live_location_ended', v_session_id
    );
  end if;
end;
$$;

-- Expire stale active rows (also used by listing queries).
create or replace function public.fv_expire_stale_live_locations()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.business_open_sessions
  set status = 'expired',
      updated_at = now()
  where status = 'active'
    and ends_at <= now();
  get diagnostics v_count = row_count;
  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.fv_expire_stale_live_locations() from public;
grant execute on function public.fv_expire_stale_live_locations() to authenticated, anon, service_role;

create or replace function public.list_active_business_open_sessions(
  p_limit int default 40
)
returns table (
  session_id uuid,
  business_id uuid,
  business_name text,
  business_type text,
  note text,
  latitude double precision,
  longitude double precision,
  started_at timestamptz,
  ends_at timestamptz,
  location_type text,
  place_label text,
  address_text text,
  status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  perform public.fv_expire_stale_live_locations();

  return query
  select
    s.id as session_id,
    s.business_id,
    b.name as business_name,
    b.business_type,
    s.note,
    coalesce(
      s.latitude,
      (select bl.latitude from public.business_locations bl
       where bl.business_id = s.business_id limit 1)
    ) as latitude,
    coalesce(
      s.longitude,
      (select bl.longitude from public.business_locations bl
       where bl.business_id = s.business_id limit 1)
    ) as longitude,
    s.started_at,
    s.ends_at,
    s.location_type,
    s.place_label,
    s.address_text,
    s.status
  from public.business_open_sessions s
  join public.businesses b on b.id = s.business_id
  where s.status = 'active'
    and s.ends_at > now()
    and b.status = 'approved'
    and coalesce(b.is_demo, false) = false
  order by s.started_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
end;
$$;

create or replace function public.list_nearby_live_locations(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_miles double precision default 15,
  p_location_type text default null,
  p_limit int default 40
)
returns table (
  session_id uuid,
  business_id uuid,
  business_name text,
  business_type text,
  note text,
  latitude double precision,
  longitude double precision,
  started_at timestamptz,
  ends_at timestamptz,
  location_type text,
  place_label text,
  address_text text,
  distance_miles double precision
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_radius double precision := greatest(0.5, least(coalesce(p_radius_miles, 15), 50));
  -- Rough degree box (~69 miles per degree lat).
  v_delta double precision := v_radius / 69.0;
begin
  perform public.fv_expire_stale_live_locations();

  return query
  select
    s.id as session_id,
    s.business_id,
    b.name as business_name,
    b.business_type,
    s.note,
    coalesce(s.latitude, bl.latitude) as latitude,
    coalesce(s.longitude, bl.longitude) as longitude,
    s.started_at,
    s.ends_at,
    s.location_type,
    s.place_label,
    s.address_text,
    (
      69.0 * sqrt(
        power(coalesce(s.latitude, bl.latitude) - p_latitude, 2) +
        power((coalesce(s.longitude, bl.longitude) - p_longitude) *
          cos(radians(p_latitude)), 2)
      )
    )::double precision as distance_miles
  from public.business_open_sessions s
  join public.businesses b on b.id = s.business_id
  left join lateral (
    select latitude, longitude
    from public.business_locations
    where business_id = s.business_id
    limit 1
  ) bl on true
  where s.status = 'active'
    and s.ends_at > now()
    and b.status = 'approved'
    and coalesce(b.is_demo, false) = false
    and coalesce(s.latitude, bl.latitude) is not null
    and coalesce(s.longitude, bl.longitude) is not null
    and coalesce(s.latitude, bl.latitude)
        between p_latitude - v_delta and p_latitude + v_delta
    and coalesce(s.longitude, bl.longitude)
        between p_longitude - v_delta and p_longitude + v_delta
    and (p_location_type is null or s.location_type = p_location_type)
  order by distance_miles asc nulls last, s.started_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
end;
$$;

revoke all on function public.list_nearby_live_locations(
  double precision, double precision, double precision, text, int
) from public;
grant execute on function public.list_nearby_live_locations(
  double precision, double precision, double precision, text, int
) to authenticated, anon;

create or replace function public.fv_notify_followers_live_nearby(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.business_open_sessions;
  v_business public.businesses;
  v_count integer := 0;
  v_follower record;
  v_until text;
begin
  select * into v_session from public.business_open_sessions where id = p_session_id;
  if not found then return 0; end if;
  select * into v_business from public.businesses where id = v_session.business_id;
  if not found or coalesce(v_business.is_demo, false) then return 0; end if;

  v_until := to_char(v_session.ends_at at time zone 'UTC', 'HH24:MI') || ' UTC';

  for v_follower in
    select bf.profile_id
    from public.business_follows bf
    left join public.user_preferences up on up.profile_id = bf.profile_id
    where bf.business_id = v_session.business_id
      and coalesce(up.push_live_nearby, true) = true
      and not exists (
        select 1 from public.live_nearby_notify_log l
        where l.profile_id = bf.profile_id
          and l.business_id = v_session.business_id
          and l.notified_at > now() - interval '3 hours'
      )
    limit 200
  loop
    insert into public.live_nearby_notify_log (profile_id, business_id, session_id)
    values (v_follower.profile_id, v_session.business_id, p_session_id)
    on conflict do nothing;

    insert into public.activity_notifications (user_id, type, title, body, payload)
    values (
      v_follower.profile_id,
      'business_live_nearby',
      v_business.name || ' is live nearby',
      coalesce(v_session.place_label, v_session.note, 'Live now')
        || ' · until ' || v_until,
      jsonb_build_object(
        'business_id', v_session.business_id,
        'session_id', p_session_id,
        'location_type', v_session.location_type
      )
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function public.fv_notify_followers_live_nearby(uuid) from public;
grant execute on function public.fv_notify_followers_live_nearby(uuid) to authenticated, service_role;

-- Owner analytics for today (excludes demo businesses from "real" adoption).
create or replace function public.fv_business_discovery_stats_today(p_business_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not (
    public.has_business_role(p_business_id, array['owner', 'manager', 'analytics_viewer']::text[], v_uid)
    or public.is_firstvue_admin()
  ) then
    raise exception 'Not allowed';
  end if;

  return (
    select coalesce(jsonb_object_agg(event_name, cnt), '{}'::jsonb)
    from (
      select event_name, count(*)::int as cnt
      from public.business_discovery_events e
      join public.businesses b on b.id = e.business_id
      where e.business_id = p_business_id
        and e.created_at >= date_trunc('day', now())
        and coalesce(b.is_demo, false) = false
      group by event_name
    ) s
  );
end;
$$;

revoke all on function public.fv_business_discovery_stats_today(uuid) from public;
grant execute on function public.fv_business_discovery_stats_today(uuid) to authenticated;

comment on table public.business_scheduled_stops is
  'Future stop schedule for mobile businesses. Distinct from LIVE NOW presence.';
comment on table public.business_launch_badges is
  'Admin-assigned launch badges (e.g. Founding Food Truck). Not purchasable.';
comment on column public.business_open_sessions.location_type is
  'Reusable live-location category (food_truck, popup, mobile_service, etc.).';
