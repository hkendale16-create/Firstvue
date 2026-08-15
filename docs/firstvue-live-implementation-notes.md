# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phase 2 complete — stopped)

## Architecture snapshot (reuse)

### Shell / navigation
- Bottom nav unchanged
- VUE tab hosts `VUE | ● LIVE` switch (`discovery_feed_screen.dart`)
- LIVE body: `live_home_shell_screen.dart`

### LIVE Home (Phase 2)
- Tokens: `lib/theme/live_tokens.dart`
- Data: `lib/services/live_home_service.dart` (events + real going counts)
- Widgets: `lib/widgets/live/*` (categories, Right Now cards, VUE strip)
- City heading from `UserPreferencesService` (never hardcodes Atlanta)
- Map CTA stub until `liveMapEnabled` / Phase 4
- Food Truck LIVE: **not in backend** — honest empty/gap copy, no fake counts

### Events / attendance
- `community_events` via `ThingsToDoService`
- Going counts: `event_attendance` where status=`attending` (read-only)
- Opens existing `EventProfileSheet`
- Proto fallback events excluded from Right Now

### Feature flags
- `liveModeEnabled` default true
- `liveMapEnabled` still false (CTA shows snackbar)

## Design references
- PNG zip still not in repo; Phase 2 used uploaded design pictures as SoT
- Placeholder: `docs/design-references/firstvue-live/`

## Files changed (Phase 2)
- `lib/theme/live_tokens.dart` (new)
- `lib/services/live_home_service.dart` (new)
- `lib/screens/live_home_shell_screen.dart` (replaced empty shell)
- `lib/widgets/live/live_category_row.dart` (new)
- `lib/widgets/live/live_right_now_card.dart` (new)
- `lib/widgets/live/live_vue_feed_strip.dart` (new)
- `test/live_mode_shell_test.dart`
- `test/live_home_screenshot_test.dart`
- `docs/firstvue-live-implementation-notes.md`

## Decisions
1. Right Now ranked by lifecycle (LIVE → starting soon → upcoming); ended hidden.
2. City filter soft-falls back to all real events when city match is empty (early access).
3. No fabricated distances, here-now, or food-truck open counts.
4. Explore Live Map is visible but stubbed (Phase 4).

## Tests run
- `flutter analyze` on Phase 2 files — clean
- `flutter test test/live_mode_shell_test.dart test/live_home_screenshot_test.dart test/vue_landing_test.dart` — pass

## Visual comparison vs reference 01 (uploaded pictures)
Matched: dark chrome, FirstVue label, circular categories, Right Now heading, horizontal cards (~168×220, r=14), LIVE pills, Map CTA, VUE FEED section, empty states.
Known diffs (intentional / data gaps): no attendee avatar stack (presence Phase 3); no distance chips (events lack lat/lng); no Food Truck LIVE aggregate card; map not implemented; mode switch remains above shell from Phase 1.

## Next (blocked on approval)
- Phase 3: LIVE Event Detail + Hot / Going / I’m Here presence
