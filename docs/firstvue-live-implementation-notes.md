# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phase 4 complete — stopped)

## Architecture

### Mode shell
- VUE|LIVE switch → LIVE Home → Event Detail / Live Map

### Map (Phase 4)
- **No prior interactive map SDK** — added `flutter_map` + `latlong2` (smallest path)
- Dark Carto tiles (`dark_all`) for night aesthetic
- Pins from: event lat/lng OR event→business_locations join OR Food Truck businesses with coords
- Debounced viewport reload (450ms, only after move end — not every frame)
- Client filter cache on loaded pins
- Recenter via `LocationService` (Atlanta coords only as GPS fallback)
- CTA: Explore Live Map → `LiveMapScreen`

### Engagement (Phase 3)
- Going / Hot / I’m Here (timed presence, no GPS)

### Flags
- `liveMapEnabled` default **true**
- presence + chat default true

## Schema
- `20261001_live_event_presence_hot.sql` — presence + hot
- `20261002_live_event_geo.sql` — nullable `community_events.latitude/longitude` + index

## Files (Phase 4)
- `pubspec.yaml` (flutter_map, latlong2)
- `lib/services/live_map_service.dart`
- `lib/screens/live_map_screen.dart`
- `lib/screens/live_home_shell_screen.dart` (CTA wire)
- `lib/config/feature_flags.dart`
- `supabase/migrations/20261002_live_event_geo.sql`
- `test/live_map_test.dart`

## Visual vs ref 04
Matched: dark map, glowing LIVE pins, soft radius, compact popup, filter chips, recenter.
Diffs: OSM/Carto tiles (not custom 3D buildings); Food Truck pins show real locations without fabricated LIVE status; empty area copy when no geo data.

## Gaps
- Most events still lack coordinates until organizers set lat/lng or link a business location
- No city-wide realtime subscription (by design)

## Next (blocked)
- Phase 5: lifecycle polish + Heating Up
