# Food Trucks + Live Locations — Completion Report

## 1. Industry catalog
- Added `food-truck` (`Food Truck`) under `food-dining`, template `food`, sortOrder `24`.
- `_mapDisplayType` checks food truck / foodtruck / food-truck **before** generic food → restaurant.

## 2. Explore destination
- New `ExploreSection.foodTrucks` labeled **Food Trucks**, placed immediately after **Food**.
- Selecting the chip pushes `FoodTrucksDiscoveryScreen` via `FirstVuePageRoute` (no post feed).
- Classifier routes food-truck industry / “food truck” hints to `foodTrucks` instead of only `food`.
- `ExploreFeedService` returns an empty page for `foodTrucks` (dedicated screen owns discovery).

## 3. Live business open service
- Session fields: `locationType`, `placeLabel`, `addressText`, `status`, `distanceMiles?`.
- `startLive` → RPC `start_business_live_location`.
- `extend` → RPC `extend_business_open_session`.
- `listNearby` → RPC `list_nearby_live_locations`.
- Existing `start` / `end` / `listActive` preserved; new columns mapped optionally.
- `isFoodTruck` also true when `locationType == food_truck`.

## 4. New services
- `BusinessScheduledStopsService` — owner CRUD + list-for-business + upcoming today (business / public).
- `BusinessLaunchBadgeService` — active badges; `founding_food_truck` display label.
- `BusinessDiscoveryAnalyticsService` — `recordEvent` + `fetchTodayStats` (RPC).
- `FoodTruckDiscoveryService` — Live Now / Later Today / Trending / Upcoming Stops from real open sessions, scheduled stops, and approved food-truck businesses. Trending only when `popularity_score` / `demand_score` are present and > 0 (no invented metrics).

## 5. Discovery UI
- `FoodTrucksDiscoveryScreen`: heading **Food Trucks Near You**, Map|List (map opens `LiveMapScreen` with food-trucks filter), filters Open Now / Live Now / Distance / Cuisine / Trending / Today / Later Today, sections Live Now / Later Today / Trending / Upcoming Stops.
- Lightweight rows (no bulky cards); FirstVueTheme light/dark aware.

## 6. Go Live wizard
- `LiveBusinessOpenControls` wizard: current location **or** place label / lat-lng, duration 1h / 2h / 4h / until closing (~6h) / custom, optional note, Confirm Go Live.
- When live: Extend +1h and End; uses `startLive` RPC.

## 7. Pin sheet
- `LiveFoodTruckPinSheet`: name, LIVE · distance, until time, cuisine/type, Menu | Directions | Follow, open full profile.
- Directions re-validates that the session is still active and has coordinates.

## 8. Profile enhancements
- Food truck / live profiles show LIVE NOW banner (place / distance / until) with Directions.
- Founding / launch badges when present.
- Today’s Schedule from `business_scheduled_stops`.
- Menu shows **Sold Out** for unavailable items.

## 9. Preferences
- `UserPreferences.pushLiveNearby` + `updatePushLiveNearby` wired to `user_preferences.push_live_nearby` (local cache fallback). Settings toggle left optional.

## 10. Tests
- `test/food_trucks_live_locations_test.dart` covers migration presence, `isFoodTruck`, industry mapping, explore label/order, classifier, and no checkout/payment code in food-truck screens/services.

## 11. Ordering / payments
- **Not implemented** (by design). No checkout, Stripe, or order flows in food-truck UI or the live-locations migration.

## 12. Reuse
- Reuses `FirstVuePageRoute`, `LiveMapScreen` (optional initial filter), `LocationService`, `BusinessMenuService`, `EntityFollowButton`, activity/discovery analytics events, and `FirstVueTheme` / `LiveTokens`.
