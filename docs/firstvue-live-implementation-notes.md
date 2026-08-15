# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (inspection only — no LIVE code yet)

## Architecture snapshot (reuse)

### Shell / navigation
- Bottom nav: `lib/widgets/firstvue_bottom_nav.dart` — Home(0), Explore(1), VUE(2), Feeds(3), Profile(4)
- Shell: `lib/main.dart` (`_FirstVueShellState`) — tab Offstage stack; Home = `_buildHomeTab()`
- Primary VUE screen: `lib/screens/discovery_feed_screen.dart` + `DiscoveryFeedService`
- Routes: `lib/navigation/firstvue_page_route.dart`, `entity_navigation.dart` (`openEvent` → `EventProfileSheet`)

### Home (current FirstVue)
- Header: avatar, `FirstVueAnimatedHeaderTitle`, `HomeCityChip`, notifications
- Body: `HomeDiscoverySection` (Trending / New / Recommended / Events / …)
- City preference: `UserPreferencesService` + `HomeCityChip` (label, not GPS pin)

### Events
- Model/service: `ThingsToDoService` / `CommunityEvent` (`lib/services/things_to_do_service.dart`)
- Table: `community_events` (`event_at`, `location_label`, cover paths, status; **no lat/lng in app model**)
- UI: `EventProfileSheet`, `EditEventScreen`, `EventPlannerScreen`
- Attendance: `event_attendance` via `EventSocialService` (`attending` | `interested` | `not_attending`)
- Follows: `event_follows`
- Open today: sheet, not a full-screen LIVE detail

### VUE / posts
- Discovery mosaic feed (not a separate VUE DB)
- Posts can link `community_news_posts.event_id` (migrations present)
- Interactions: feed comments / sparks / impressions services

### Messaging / event chat
- `FvMessagingService.enableEventChat` / `joinEventChat` → RPC `fv_msg_enable_event_chat`
- UI: `lib/messaging/screens/event_conversation_page.dart`
- Tables: `fv_msg_*` including `fv_msg_event_settings` / channels

### Location / maps
- GPS: `LocationService` (geolocator) — Near Me style use
- Business geo: `business_locations.latitude/longitude` (+ index)
- Profile preferred lat/lng columns exist
- **No interactive map SDK** in `pubspec.yaml` (no google_maps_flutter / mapbox / flutter_map)
- Directions pattern today: `url_launcher` to external maps URLs
- Places autocomplete hits `maps.googleapis.com` in `smart_address_field.dart`

### Food trucks
- Business type catalog only (`Food Truck` under Food & Dining)
- **No** live stop / expires_at / mobile location subsystem found

### Theme
- `lib/theme/firstvue_theme.dart` — gold/bronze accents, dark palette
- LIVE will need additive status tokens (live red, truck green, market purple) — do not scatter hardcoded colors

### Feature flags
- `lib/config/feature_flags.dart` — `liveStreamingEnabled` (Go Live streaming, **unrelated**), `paymentsEnabled`
- Pattern: `bool.fromEnvironment` — extend for `live_mode` etc.

### Local preference pattern to copy
- `VueTabPreference` (`shared_preferences`) — good model for VUE|LIVE mode persistence

### Analytics
- Post impressions exist; **no** general LIVE event-tracking layer yet
- Early Access LIVE metrics need additive instrumentation later

### Do not confuse
- `LiveStreamService` / `live_stream_eligibility` = creator livestream eligibility, **not** LIVE discovery mode

## Design references
- Expected path: `docs/design-references/firstvue-live/`
- `firstvue_live_design_refs.zip` **not found** in workspace at inspection
- Prompt attached mockup images (descriptions) used as interim visual SoT until PNGs are placed:
  - `01_live_home_reference.png`
  - `02_live_event_detail_reference.png`
  - `03_live_interactions_reference.png`
  - `04_live_map_reference.png`
  - `00_locked_live_design_full.png`, `00_locked_live_map_source_full.png`

## Files changed (this step)
- `docs/firstvue-live-implementation-notes.md` (created)
- `docs/design-references/firstvue-live/` (empty dir created)

## Decisions (inspection)
1. LIVE is a **mode overlay**, not a second app — switch lives near primary shell/header; keep bottom nav + auth.
2. Prefer attaching LIVE shell to existing Home or VUE primary surface with minimal `main.dart` churn.
3. Reuse `event_attendance` for **Going**; add separate time-limited **I'm Here** presence (do not overload attendance).
4. Map phase requires **provider decision** — no in-app map today; do not add a package until Phase 4 approval after smallest-path report.
5. Food Truck LIVE cards: only if live-location data exists; otherwise show real business/event data and document gap.
6. Git: **no push** until explicit approval (per controller prompt).

## Known gaps / risks
- Events lack structured geo in app model → distance/map need schema or business_location join
- No Here Now / Hot / Heating Up tables yet
- No food-truck live stops
- No interactive map stack
- Design PNG files not yet in repo

## Next (blocked on approval)
- Phase 1 only: VUE|LIVE switch + empty LIVE shell + `live_mode` flag + local mode persistence
