-- =============================================================================
-- FirstVue LIVE Phase 4: optional event coordinates for map pins
-- Additive. Prefer business_locations join when business_id is set.
-- =============================================================================

alter table public.community_events
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

create index if not exists community_events_geo_idx
  on public.community_events (latitude, longitude)
  where latitude is not null and longitude is not null;

comment on column public.community_events.latitude is
  'Optional event pin latitude for LIVE map. Prefer business_locations when linked.';
comment on column public.community_events.longitude is
  'Optional event pin longitude for LIVE map. Prefer business_locations when linked.';
