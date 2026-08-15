# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phase 1 complete — stopped)

## Architecture snapshot (reuse)

### Shell / navigation
- Bottom nav: `lib/widgets/firstvue_bottom_nav.dart` — Home(0), Explore(1), VUE(2), Feeds(3), Profile(4)
- Shell: `lib/main.dart` — unchanged in Phase 1
- Primary VUE screen: `lib/screens/discovery_feed_screen.dart` — **hosts VUE|LIVE switch**
- Routes: `lib/navigation/firstvue_page_route.dart`, `entity_navigation.dart`

### Events / VUE / messaging / maps / food trucks
- Unchanged in Phase 1 (see prior inspection notes)

### Theme
- `lib/theme/firstvue_theme.dart` — gold + coral used by mode switch

### Feature flags (`lib/config/feature_flags.dart`)
- `liveModeEnabled` (FIRSTVUE_LIVE_MODE, default **true**) — Phase 1
- `liveMapEnabled`, `liveEventPresenceEnabled`, `liveEventChatEnabled`, `liveFoodTrucksEnabled`, `liveHeatActivityEnabled` — stubs default **false**
- `liveStreamingEnabled` remains separate (creator Go Live)

### Local preference
- `LiveModePreference` (`firstvue_experience_mode`) — mirrors `VueTabPreference` pattern

## Design references
- Path: `docs/design-references/firstvue-live/` (still empty — zip not in repo)

## Phase 1 files changed
- `lib/config/feature_flags.dart`
- `lib/services/live_mode_preference.dart` (new)
- `lib/widgets/vue_live_mode_switch.dart` (new)
- `lib/screens/live_home_shell_screen.dart` (new)
- `lib/screens/discovery_feed_screen.dart` (switch + empty LIVE shell)
- `test/live_mode_shell_test.dart` (new)
- `docs/firstvue-live-implementation-notes.md`

## Decisions
1. Mode switch lives on the **VUE tab header** (default landing) — not a second app shell.
2. LIVE selected → empty `LiveHomeShellScreen`; VUE selected → existing mosaic unchanged.
3. Preference is local only; defaults to VUE; invalid/missing → VUE.
4. Disable LIVE UI with `--dart-define=FIRSTVUE_LIVE_MODE=false` (falls back to classic "VUE" title).
5. No DB/RLS changes in Phase 1.

## Tests run
- `flutter analyze` on Phase 1 files — clean
- `flutter test test/live_mode_shell_test.dart test/vue_landing_test.dart` — pass

## Known issues / gaps
- Design PNGs not yet in repo
- LIVE shell is intentionally empty (Phase 2 builds Right Now)
- No screenshot vs 01 reference yet (shell only)

## Next (blocked on approval)
- Phase 2: LIVE Home / city Right Now cards + Explore Live Map CTA (stub)
