# Food Trucks + Live Locations — Completion Report

**Branch:** `cursor/food-trucks-live-locations-240e`  
**Date:** 2026-08-15  
**Git push:** Held until explicitly authorized.

---

## 1. Files changed (high level)

| Area | Paths |
|------|--------|
| Schema | `supabase/migrations/20261011_entity_live_locations_food_trucks.sql` |
| Industry / Explore | `lib/data/industry_catalog.dart`, `lib/models/explore_section.dart`, `lib/screens/explore_screen.dart`, `lib/utils/explore_classifier.dart`, `lib/services/explore_feed_service.dart`, `lib/constants/business_types.dart` |
| Live location services | `lib/services/live_business_open_service.dart`, `lib/services/food_truck_discovery_service.dart`, `lib/services/business_scheduled_stops_service.dart`, `lib/services/business_launch_badge_service.dart`, `lib/services/business_discovery_analytics_service.dart` |
| UI | `lib/screens/food_trucks_discovery_screen.dart`, `lib/widgets/live/live_business_open_controls.dart`, `lib/widgets/live/live_food_truck_pin_sheet.dart`, `lib/screens/firstvue_business_profile_screen.dart`, `lib/screens/live_map_screen.dart`, `lib/screens/settings_preferences_screen.dart` |
| Prefs / tests / docs | `lib/services/user_preferences_service.dart`, `test/food_trucks_live_locations_test.dart`, this report |

## 2. Supabase / schema changes

- Industry seed: `food-truck` under `food-dining`
- Extended `business_open_sessions` with reusable fields: `location_type`, `status`, `place_label`, `address_text`, `event_id`
- `business_scheduled_stops` (future stops ≠ LIVE NOW)
- `business_launch_badges` (Founding Food Truck / founding member / launch partner)
- `business_discovery_events` (append-only analytics)
- `user_preferences.push_live_nearby` + cooldown table `live_nearby_notify_log`
- Stub `mobile_business_promotions` (draft only; no payments)
- RPCs: enhanced start/end, `start_business_live_location`, `extend_business_open_session`, `list_nearby_live_locations`, `fv_expire_stale_live_locations`, follower notify, owner stats today

## 3. RLS changes

- Scheduled stops: public read of scheduled rows for approved businesses; owners/managers CRUD
- Launch badges: public read of active non-demo badges; **admin-only** write
- Discovery events: authenticated insert of own rows; owners/analytics_viewer/admin read
- Live notify log: user read own; writes via SECURITY DEFINER notify RPC
- Mobile promotions: public read of active only; **no client write policies**
- Live location start/extend/end remain SECURITY DEFINER + `has_business_role(owner|manager)`

## 4. Existing systems reused

- Business entity / profiles / menus / follows / messaging
- `business_open_sessions` (Phase 8) as the live-location backbone
- LIVE map (`LiveMapScreen` / food-truck pin filter)
- `LocationService`, Explore chip row, FirstVue theme / Live tokens
- `activity_notifications` for follower live alerts
- Menu `is_available` → Sold Out display
- No duplicate auth or profile system

## 5. New Food Truck features

- First-class `food-truck` industry + Explore **Food Trucks** chip
- Dedicated discovery: **Food Trucks Near You** with Map | List, filters, Live Now / Later Today / Trending / Upcoming Stops
- Profile LIVE NOW banner, founding badge, today’s schedule, directions to **active** live coords only
- Owner Go Live wizard + Add scheduled stop
- Live nearby notification preference

## 6. Live Location implementation

Reusable `location_type` on open sessions (`food_truck`, `mobile_coffee`, `popup_vendor`, …). One active session per business; auto-expire via `status`/`ends_at`; Extend / End for owners; GPS optional (manual place/coords supported). Does **not** continuous-track the owner.

## 7. Scheduled Stop implementation

Separate `business_scheduled_stops` with date/time/place/coords/note. Clearly labeled Scheduled vs LIVE NOW; schedule start does **not** auto-claim physical presence.

## 8. Map integration

Reuses LIVE map food-truck filter; discovery Map mode opens `LiveMapScreen`; pin sheet for lightweight truck preview (Menu / Directions / Follow / full profile).

## 9. Analytics added

Events: profile/live/menu/directions/follow/share, live start/extend/end, scheduled_stop_viewed, vue/event opened from food truck. Owner `fv_business_discovery_stats_today`. Demo businesses excluded from public live lists and founding badge public reads.

## 10. Cost / performance

- Nearby queries use bounding box + limit (≤100)
- Indexes on status/geo/type/expiration
- Expire-on-read via RPC (no `now()` in indexes)
- No city-wide realtime fan-out of every business; existing open-session realtime retained
- No continuous GPS writes

## 11. Intentionally left disabled

- Food ordering / checkout / Apple Pay / Google Pay / wallets / delivery / restaurant payouts
- Paid Boost My Truck / Lunch Rush / Featured Nearby activation (schema stub only)
- Fake popularity, ratings, or manufactured live activity

## 12. Issues requiring attention

1. Apply `20261011_…` migration to staging Supabase (MCP not authenticated in this agent).
2. Founding Food Truck badges require **admin assignment** — none auto-granted.
3. Cuisine filter currently matches `business_type` / label text until structured cuisine fields are richer.
4. Flutter SDK unavailable in this environment — run `flutter test test/food_trucks_live_locations_test.dart` locally.
5. Confirm `activity_notifications` insert path from SECURITY DEFINER notify RPC in your project’s RLS setup.
6. Do not enable payment flags for truck promos without separate approval.

**STOP — do not push until you authorize.**
