# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phase 6 polish + Mapbox hardening — complete)

## Map provider
- **Mapbox** on iOS/Android when `MAPBOX_ACCESS_TOKEN` is set (`mapbox_maps_flutter`)
  - Dark style default: `mapbox://styles/mapbox/dark-v11`
  - Pitch ~55° for 3D buildings; style-loaded pass enables building/extrusion layers
  - Optional `MAPBOX_STYLE_URI` for custom neon Studio style
  - Ornament chrome inset so logo/attribution clear LIVE UI
  - Selected pin glow + `customData` pinId mapping; serialized annotation sync
- **Fallback**: Carto dark `flutter_map` (web / no token / desktop)
- Gate UI on `MapboxConfig.canUseNativeMap` (token + iOS/Android), not token alone
- Conditional import: `live_map_surface.dart` → native vs osm

## Phase 5 Heating Up
- RPC `live_event_heat_scores(uuid[])` — recent Going / Here Now / Hot / VUEs
- Statuses only when thresholds met: Active / Heating Up / Hot
- Shown on Right Now cards + event detail (no fabricated heat)

## Phase 6 polish / regression
- Stale viewport load cancellation; GPS camera apply after resolve
- Food Trucks filter/fetch gated by `FIRSTVUE_LIVE_FOOD_TRUCKS` (default off)
- Ending-soon lifecycle in final LIVE hour (until `ends_at` exists)
- Directions prefer event lat/lng when present
- Engagement fetch parallelized; presence/hot no longer list other profile ids
- Migration `20261004`: RPC-only presence writes, own-row SELECT, `event_hot_count`, heat batch cap 100
- Motion: category scale, Right Now card enter, pin popup switcher
- Removed dead “See All” / stub phase copy

## Secrets required
- `MAPBOX_ACCESS_TOKEN` (required for 3D Mapbox on device)
- `MAPBOX_STYLE_URI` (optional custom neon style)

## Migrations
- `20261001` presence/hot
- `20261002` event geo
- `20261003` heat scores RPC
- `20261004` Phase 6 hardening

## Next (operator)
- Apply migrations `20261001`–`20261004`
- Add Mapbox token and run on iOS/Android with `--dart-define=MAPBOX_ACCESS_TOKEN=...`
- Optional custom neon `MAPBOX_STYLE_URI` in Mapbox Studio
