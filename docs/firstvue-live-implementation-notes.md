# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (SQL unblock + Mapbox run path)

## Status
LIVE Mode Phases 1–6 are in code. Operator SQL: use the **minimal unblock** (or the short heat-only fix) and move on — do not re-run the old #1–#4 scripts that had `now()` index / `[1:100]` syntax issues.

## Map provider
- **Mapbox** on iOS/Android when `MAPBOX_ACCESS_TOKEN` is set (`mapbox_maps_flutter`)
  - Dark style default: `mapbox://styles/mapbox/dark-v11`
  - Pitch ~55°; buildings enabled on style load
  - Optional `MAPBOX_STYLE_URI` for custom neon Studio style
- **Fallback**: Carto dark `flutter_map` (web / no token / desktop)
- Gate: `MapboxConfig.canUseNativeMap`

## Run with Mapbox (next step)
```bash
export MAPBOX_ACCESS_TOKEN=pk.YOUR_PUBLIC_TOKEN
# optional:
# export MAPBOX_STYLE_URI=mapbox://styles/you/your-neon-style
./scripts/run-with-mapbox.sh ios      # or android
```
Or:
```bash
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk....
```

## SQL (done / finishing)
Preferred one-shot: `supabase/migrations/20261005_live_minimal_unblock.sql`  
If that failed only on heat scores, run the fixed `live_event_heat_scores` from the same file (uses `limit 100`, not `[1:100]`).

Older files (`20261001`–`20261004`) are kept for history; prefer `20261005` + heat fix.

## Secrets
- `MAPBOX_ACCESS_TOKEN` (required for 3D on device)
- `MAPBOX_STYLE_URI` (optional)

## App checklist after SQL + token
1. VUE tab → switch to LIVE
2. Right Now cards open event detail (Going / Hot / I’m Here)
3. Explore Live Map → pitched Mapbox (3D icon) on iOS/Android with token
4. Heat badges only when real activity meets thresholds
