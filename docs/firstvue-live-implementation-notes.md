# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phases 1–10 complete in code)

## How many phases?
**10 total.** That is the full LIVE Mode roadmap for this track.

| Phase | What |
|------|------|
| 1 | VUE \| LIVE switch + shell |
| 2 | LIVE Home Right Now |
| 3 | Event detail (Going / Hot / I’m Here) |
| 4 | Explore Live Map |
| 5 | Heating Up scores |
| 6 | Polish + Mapbox path + hardening |
| 7 | Event `ends_at` lifecycle |
| 8 | Food Truck / business open sessions |
| 9 | Event map pin (lat/lng) in Edit Event |
| 10 | LIVE Realtime refresh (open sessions + engagement) |

## Deferred operator work (not more product phases)
- Apply SQL migrations `20261005`–`20261008` (and any unfinished earlier LIVE SQL)
- Add `MAPBOX_ACCESS_TOKEN` and run `./scripts/run-with-mapbox.sh`

I cannot apply SQL from this cloud agent until Supabase MCP is authenticated in Cursor.

## Phase 9
- Edit Event: **Use current location** / Clear map pin
- Persists `latitude` / `longitude` on `community_events`

## Phase 10
- `LiveRealtimeService` debounced refresh on LIVE Home open sessions
- Event detail quiet-refresh on presence / hot reaction changes
- Migration `20261008` adds tables to `supabase_realtime` publication
- Open session start tries current GPS (falls back to business location)

## Migrations to apply later
1. `20261005_live_minimal_unblock.sql` (or heat-only if partial)
2. `20261006_live_event_ends_at.sql`
3. `20261007_live_business_open_sessions.sql`
4. `20261008_live_realtime_publication.sql`
