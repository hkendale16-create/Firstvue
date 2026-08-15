# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phases 7–8 — ends_at + business open sessions)

## Status
Phases 1–8 are in code. Mapbox token + applying SQL remain operator-deferred.

## Phase 7 — Event ends_at
- Column `community_events.ends_at` (migration `20261006`)
- Honest LIVE / ENDING SOON when end is set; start-only heuristic otherwise
- Edit Event: optional Ends At picker
- Detail + map/home lifecycle wired

## Phase 8 — Food Truck / business open sessions
- Table `business_open_sessions` + RPCs (migration `20261007`)
- Flag `FIRSTVUE_LIVE_FOOD_TRUCKS` default **true**
- LIVE Home Food/Businesses + Right Now from **active** sessions only
- Map Food Trucks = open session pins with coords (not static directory pins)
- Owner preview: **We’re open — go LIVE** / End session (4h default, max 12h)

## Mapbox (deferred)
- `./scripts/run-with-mapbox.sh` + `MAPBOX_ACCESS_TOKEN`

## SQL to apply later (operator)
1. `20261005_live_minimal_unblock.sql` (or heat-only fix if already partial)
2. `20261006_live_event_ends_at.sql`
3. `20261007_live_business_open_sessions.sql`

## Secrets
- `MAPBOX_ACCESS_TOKEN` (optional until 3D map needed)
- `MAPBOX_STYLE_URI` (optional)
