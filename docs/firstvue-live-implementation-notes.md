# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phase 5 + Mapbox wiring — stopped)

## Map provider
- **Mapbox** on iOS/Android when `MAPBOX_ACCESS_TOKEN` is set (`mapbox_maps_flutter`)
  - Dark style default: `mapbox://styles/mapbox/dark-v11`
  - Pitch ~55° for 3D buildings
  - Optional `MAPBOX_STYLE_URI` for custom neon Studio style
- **Fallback**: Carto dark `flutter_map` (web / no token / desktop)
- Conditional import: `live_map_surface.dart` → native vs osm

## Phase 5 Heating Up
- RPC `live_event_heat_scores(uuid[])` — recent Going / Here Now / Hot / VUEs
- Statuses only when thresholds met: Active / Heating Up / Hot
- Shown on Right Now cards + event detail (no fabricated heat)

## Secrets required
- `MAPBOX_ACCESS_TOKEN` (required for 3D Mapbox)
- `MAPBOX_STYLE_URI` (optional custom neon style)

## Migrations
- `20261001` presence/hot
- `20261002` event geo
- `20261003` heat scores RPC

## Next
- Phase 6 polish/regression
- Apply migrations + add Mapbox token to see 3D neon map on device
