# FirstVue Tonight + Scenes — Implementation Spec

**Status:** Product + engineering blueprint. Not implemented yet.  
**Audience:** Implement against this document without inventing a second events stack.  
**North star:** Open the app → see tonight in your city → see who you know is going → RSVP → talk in the scene → post what happened.

This spec keeps the existing LIVE, events, communities, venues, and monetization foundations. It changes **default experience, information architecture, and the social loop** so FirstVue reads as an event-focused nightlife community — not a beauty-pro discovery app with events bolted on.

---

## 1. Product thesis

FirstVue already has three products in one:

| Layer | What exists | Role after this pivot |
|-------|-------------|------------------------|
| Local business discovery | HOME carousels, beauty/pros, rentals | Supporting. Keep data; de-emphasize in nav and store copy. |
| Social platform | VUE mosaic, FEEDS, stories, shoutouts | Content layer *around* nights out. Not the front door. |
| LIVE + events + communities | Right Now, map, Going/Hot/I'm Here, hubs, event chat | **The product.** Tonight is home. Scenes are identity. Venues pay to be seen. |

**Positioning line (replace "SEE FIRST. BOOK FIRST."):**

> See what's live tonight. Connect with your scene. Show up.

**One-sentence product:** FirstVue is the place you check before you go out — what's happening, who's going, and where your scene is tonight.

---

## 2. The loop (do not break this)

Every screen should support this path. If a new feature does not sit on this loop, it is out of scope for this track.

```
Open app
  → Tonight (city + Right Now + tonight's events + open venues)
    → Event / venue card
      → Friends going (social proof)
        → Going / Interested
          → Event chat + Scene chat
            → I'm Here (during)
              → Post VUE after
                → Scene feed (last night)
```

Shareable event links (`?event=`) are how the loop starts from outside the app. That path is currently broken (share URL exists, deep-link handler does not).

---

## 3. What we will not do

- Do not create a second events table. Extend `community_events`.
- Do not create a second community system. Reposition `community_hubs` as **Scenes** and `communities` as **Crews / groups inside a scene**.
- Do not replace encrypted messaging. Promote the existing Messages / Events shell.
- Do not turn on Stripe, ticketing, or payouts in this track unless a later phase explicitly says so.
- Do not delete beauty, rentals, or professional booking. Hide or demote them.
- Do not ship a full club-crawl / table-booking / guest-list product in v1.
- Do not expose every attendee to every user. Friends-going is a **follow-graph intersection**, not a public guest list.

---

## 4. Information architecture

### 4.1 Current (keep working during Phase 0–1)

```
HOME | FEEDS | VUE (center, default) | EXPLORE | PROFILE
VUE tab can switch VUE ↔ LIVE via LiveModePreference (defaults to VUE)
Messages is a stacked route, not a tab
Event Planner is buried in Settings
```

### 4.2 Target (Phase 2+, after Tonight works)

```
TONIGHT | SCENES | CREATE (center) | INBOX | PROFILE
```

| Tab | Reuses | Purpose |
|-----|--------|---------|
| **TONIGHT** | `LiveHomeShellScreen` + map + tonight query | Default landing. City, Right Now, tonight, open venues, friends going. |
| **SCENES** | `communities_screen` + hub detail + joined events | Your scenes, crews, upcoming nights. |
| **CREATE** | Existing composers | Post VUE, create event, check in (I'm Here). |
| **INBOX** | `MessagingShellScreen` | Scenes + event chats + DMs. Promote from stacked route. |
| **PROFILE** | Existing profile | You, nights out, scenes you belong to. |

### 4.3 Recommended rollout of nav (do not jump to 4.2 on day one)

**Phase 0 — no nav rename.** Change defaults only:

- Default experience mode = LIVE (`LiveModePreference`).
- Keep landing tab as center tab (`FirstVueBottomNav.vueIndex`) so LIVE Home is what people see.
- Update first-launch tutorial copy to talk about Tonight, not generic VUE.

**Phase 1 — Tonight as the name of LIVE Home.** Keep five tabs. Relabel the center tab visually from VUE to TONIGHT when LIVE is active. HOME stays as broader discovery.

**Phase 2 — nav reshape** only after Tonight + friends-going + event deep links are live and used.

Reason: renaming tabs before the Tonight surface is dense will feel empty. Density first, chrome second.

### 4.4 Files that own the default experience

| Concern | File | Change |
|---------|------|--------|
| Landing tab | `lib/main.dart` (`FirstVueHome`, `_consumeLandingTab`) | Stay on `vueIndex` for Phase 0–1. |
| VUE vs LIVE default | `lib/services/live_mode_preference.dart` | Default `_cached` and `parse()` fallback to `live` for new installs. Existing `vue` preference still wins. |
| Switch widget | `lib/widgets/vue_live_mode_switch.dart` | Optional: label LIVE as TONIGHT. |
| Shell | `lib/screens/discovery_feed_screen.dart` | When LIVE, keep embedding `LiveHomeShellScreen`. |
| Tests | `test/vue_landing_test.dart`, `test/live_mode_shell_test.dart` | Update expected default mode. |

**Migration rule for preference:** If `firstvue_experience_mode` is unset, default LIVE. If the user previously saved `vue`, keep VUE. Do not force existing users off VUE.

---

## 5. Tonight hub (the home surface)

### 5.1 What exists

`LiveHomeShellScreen` already loads a `LiveHomeSnapshot`:

- City heading (`LiveHomeService.rightNowHeading`)
- Ranked Right Now events (excludes `proto-*`)
- Open businesses / food-truck sessions
- VUE strip
- Category row (events / people / …)
- CTA into `LiveMapScreen`

`LiveRightNowItem` already has `goingCount`, lifecycle, heat, and optional `businessId`.

### 5.2 Target layout (extend the shell — do not replace it)

Order on Tonight / LIVE Home:

1. **City chip + date** — reuse HOME city chip pattern (`HomeCityChip` / user prefs). Heading stays city-aware. Never hardcode a city.
2. **Tonight strip** — events whose `starts_at` is today in the user's local timezone, plus events already LIVE. This is missing today; Right Now ranking mixes upcoming-soon with live, but there is no "tonight only" query.
3. **Right Now** — keep current ranked live / starting-soon / heating-up cards.
4. **Open now** — nightlife + food venues with `business_open_sessions` (already in snapshot as `openBusinesses`).
5. **Friends going** — horizontal avatar row of events where people you follow are `attending`. New.
6. **Heating up** — events with `LiveHeatStatus.hot` that are not already in the first two rows.
7. **From last night** — existing VUE strip, filtered to posts tagged to last night's events when possible.
8. **Map** — keep Explore Live Map CTA; default map filter = nightlife + events after 6pm local.

### 5.3 Tonight query (new, small)

Add to `ThingsToDoService` or `LiveHomeService`:

```
fetchTonightEvents({required String? city, required DateTime nowLocal})
```

Rules:

- Status `approved` only.
- Exclude `id` prefix `proto-`.
- `starts_at` in `[local midnight, local midnight + 36h]` **or** lifecycle is `live` / `endingSoon`.
- City filter uses the same helper as `_filterEventsForCity` in `live_home_service.dart`.
- Cap 20. Rank: LIVE first, then `starts_at` ascending, then heat, then going count.

Do not add a new table for this. It is a query over `community_events`.

### 5.4 Card UI additions

Extend `LiveRightNowCard` (`lib/widgets/live/live_right_now_card.dart`):

| Element | Source | Notes |
|---------|--------|-------|
| Lifecycle pill | already exists | LIVE / STARTING SOON / UPCOMING |
| Heat pill | already exists | HOT |
| Going count | `item.goingCount` | already on model; show as "128 going" |
| **Friends going** | new field `friendsGoingPreview` | "Maya + 2 going" with 3 avatars |
| Venue name | `event.businessName` | already on `CommunityEvent` |
| Time | `event.eventAt` | local, e.g. "10:00 PM · Midtown" |

Keep card size close to `LiveTokens.cardWidth` / `cardHeight`. Friends-going is a one-line overlay, not a second card type.

### 5.5 Empty Tonight (critical for early markets)

If `rightNow` + tonight events are empty:

- Do **not** show prototype events as social proof (`LiveHomeService` already filters `proto-*` — keep that).
- Show: city name, "Nothing live yet tonight", 3 actions: **Create a night**, **Open the map**, **Join a scene**.
- Optionally show upcoming (next 7 days) under a quieter "Coming up" header so the tab is never a blank void.

---

## 6. Friends going (the connect-people feature)

This is the highest-leverage social change. RSVP counts are weak. Seeing people you follow is why someone taps Going.

### 6.1 Data you already have

| Table | Use |
|-------|-----|
| `event_attendance` | `status in ('attending','interested','not_attending')` |
| `profile_follows` | follow graph (`FollowService`) |
| `event_presence` | I'm Here (time-limited, `LiveEventEngagementService.presenceTtl` = 4h) |
| `profiles` | display name, avatar |

`LiveEventEngagement` already returns `hereNowProfileIds` but the event detail UI does not turn that into a friends graph.

Attendance RLS today: authenticated users can read all attendance rows (`"Authenticated read attendance"`). Do **not** build a public "see everyone going" list on that. Friends-going must be a **server RPC** that only returns people the viewer follows (or who follow the viewer, if you choose mutual). Recommended v1: **people I follow who are attending**.

### 6.2 New RPC

`supabase/migrations/YYYYMMDD_event_friends_going.sql`

```
public.event_friends_going(p_event_id uuid, p_limit int default 8)
returns table (
  profile_id uuid,
  display_name text,
  username text,
  avatar_url text,
  status text
)
```

Logic:

- `auth.uid()` required.
- Join `event_attendance` to `profile_follows` where `follower_id = auth.uid()` and `following_id = attendance.profile_id`.
- `attendance.status = 'attending'` (v1). Optionally include `interested` later as a second list.
- Exclude the viewer.
- Respect private profiles: if `profiles.is_private` and the follow is not accepted, they should not appear (follow graph already encodes this if pending follows are not in `profile_follows`).
- Limit 8. Order by follow recency or attendance `created_at` desc.

Companion count RPC or extra column:

```
public.event_friends_going_count(p_event_id uuid) returns int
```

Batch variant for Tonight cards (avoid N+1):

```
public.event_friends_going_batch(p_event_ids uuid[])
returns table (event_id uuid, profile_id uuid, display_name text, avatar_url text, status text)
```

Grant execute to `authenticated` only. `security definer` is OK if it only returns follow-graph intersections and does not leak non-followed attendees.

### 6.3 Client service

New: `lib/services/event_friends_service.dart`

```
class EventFriendPreview {
  final String profileId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
}

class EventFriendsGoing {
  final int count;
  final List<EventFriendPreview> previews; // max 3 for cards, 8 for detail
}
```

Methods: `fetch(eventId)`, `fetchBatch(eventIds)`.

Do not compute this in Dart by downloading all attendance + all follows. Use the RPC.

### 6.4 Where to show it

| Surface | File | Copy |
|---------|------|------|
| Tonight card | `live_right_now_card.dart` | "Maya + 2 going" |
| Event detail | `live_event_detail_screen.dart` | Avatar row under Going / Hot / I'm Here |
| Event planner / things to do cards | `event_profile_sheet.dart`, explore event tiles | Same one-liner |
| Notifications | `activity_notifications` | "Maya is going to {event}" |

### 6.5 Invite-to-event (Phase 1, after friends-going reads work)

Reuse encrypted messaging. Do not invent a new invite table in v1.

- Button on event detail: **Invite**
- Opens existing new-message / profile picker
- Prefills share payload already used in `LiveEventDetailScreen` (`AppConfig.eventShareUrl`)
- Optional later: `event_invites (event_id, inviter_id, invitee_id, created_at)` for "X invited you" notifications

### 6.6 Privacy rules (write these into the RPC comments)

- Going is visible to people who follow you (v1).
- I'm Here stays voluntary and TTL-limited (already true).
- Never show a full public attendee directory.
- Organizer/admin tools can see counts; full export is a later promoter-tools phase.

---

## 7. Event deep links (P0, small, unblock sharing)

### 7.1 Bug

- Share URL: `AppConfig.eventShareUrl` → `https://firstvue.app/?event={id}`
- Used by `live_event_detail_screen.dart` and `event_profile_sheet.dart`
- `DeepLinkService.targetFromUri` handles `business`, `profile`, `post`, `invite` only
- `FirstVueHome._handleDeepLink` has no `event` case

### 7.2 Fix

1. `DeepLinkService.eventIdFromUri` — same pattern as `businessIdFromUri`.
2. `targetFromUri` returns `DeepLinkTarget(type: 'event', id: eventId)`.
3. `FirstVueHome._handleDeepLink` case `'event'` → fetch via `ThingsToDoService` (or a `fetchEventById`) → `LiveEventDetailScreen.open`.
4. If fetch fails or event is not approved and viewer is not organizer: snackbar "Event unavailable."
5. Tests: add cases next to existing deep-link tests if present; otherwise add `test/deep_link_service_test.dart`.

Also add `?scene=` later (hub id) using the same pattern. Not required for P0.

---

## 8. Scenes (communities, renamed in UX)

### 8.1 Mapping (no schema rename)

| User-facing | Existing entity | Table | Screen |
|-------------|-----------------|-------|--------|
| **Scene** | Community Hub | `community_hubs` | `community_hub_detail_screen.dart` |
| **Crew** | Group | `communities` | `community_detail_screen.dart` |
| **Scene feed** | Hub / community news | `community_news_posts` | already on hub detail |
| **Scene chat** | Community / group conversation | `fv_msg_*` | messaging shell |
| **Night** | Event | `community_events` | LIVE event detail |

Do **not** rename tables. Rename copy, empty states, create-flow titles, and Explore chips.

Suggested copy:

- "Create a community" → "Start a scene"
- "Groups" → "Crews" (or keep Groups if testers find Crews unclear — A/B in copy only)
- Hub about: city + vibe ("Atlanta house / warehouse") not generic org boilerplate

### 8.2 Scene page target structure

Reuse `CommunityHubDetailScreen`. Reorder sections; do not rewrite the screen.

1. Cover + name + city + member/follower counts (exists)
2. **Tonight in this scene** — events linked to this hub's groups (`community_events.community_id` already exists in SQL; **`CommunityEvent` Dart model does not expose `communityId` — add it**)
3. **Venue partners** — businesses followed by the hub or tagged nightlife in the same city (v1: manual list via existing business links if any; else hide)
4. **Feed** — existing posts
5. **Crews** — existing `_groups`
6. Primary CTAs: **Join scene**, **Tonight**, **Chat**

### 8.3 Event ↔ scene link (schema already half-there)

SQL `community_events.community_id` → `communities(id)`.

Gaps:

- `CommunityEvent` in `things_to_do_service.dart` has no `communityId`.
- Edit Event (`edit_event_screen.dart`) may not require / surface a scene or crew.
- A scene (hub) contains many groups; an event points at one group, not the hub.

**v1 rule:** Event belongs to a **crew** (`community_id`). Tonight-in-scene = events whose `community_id` is in the hub's child groups.

Add to Dart model + fetch/select lists: `communityId`.  
Add optional `hub_id` only if you need events that are scene-wide without a crew. Prefer computing via groups first to avoid a migration.

### 8.4 Scene discovery

Explore already has `ExploreSection.communities` and `ExploreSection.groups`.

Phase 1 copy: lead Explore with **Scenes**, **Tonight**, **Bars** — demote Rentals / generic Businesses below the fold.

`community_discovery_search_service.dart` stays. Add a "Nightlife / music / social" category filter if `community_hubs.category` is populated. Seed categories: `nightlife`, `music`, `food`, `arts`, `sports`, `other`.

### 8.5 Who can create a scene

Keep current hub create + leader request flow. Do not make scenes unmoderated city-wide free-for-all on day one.

For events, keep organizer approval (`community_organizer_applications`). Tonight density comes from **approved venues posting nights** and **approved organizers**, not from every user dumping parties.

---

## 9. Event detail (make it a night, not a listing)

`LiveEventDetailScreen` already has Going / Hot / I'm Here, heat, VUE posts, share, event chat.

Add, in this order:

| Block | v1? | Notes |
|-------|-----|-------|
| Friends going row | Yes | Section 6 |
| Invite | Yes | Share + message picker |
| Venue card | Yes | If `event.businessId` set, tappable → `FirstVueBusinessProfileScreen` (LIVE home already does this for business-kind items) |
| Scene chip | Yes | If `communityId` resolved to hub/crew name |
| Cover / time / map pin | Exists | Keep |
| Dress / age / cover | Later | Needs new nullable columns; do not block v1 |
| Tickets | No | Flag stays off |
| Lineup / DJ | Later | Rich text in description is enough for v1 |

**RSVP model (keep both layers, align copy):**

- LIVE: Going / Hot / I'm Here (`LiveEventEngagementService` writes `event_attendance` as attending)
- Planner/social: attending / interested / not_attending (`EventSocialService`)

v1 copy on Tonight: **Going** and **Interested** only. Map Going → `attending`. Keep Hot as energy, not RSVP.

---

## 10. Venue (business) as nightlife surface

Nightlife is already a template in `lib/data/industry_catalog.dart`:

- Tabs: DRINKS + core
- Modules: Drinks, Happy hour, Events, Hours, Age, Reservations, Location
- Actions: Follow, Message, Reserve

`business_types.dart` already has bar, lounge, nightclub, sports bar.

### 10.1 v1 venue page changes (no new product)

On `FirstVueBusinessProfileScreen` when `IndustryTemplate.nightlife`:

1. **Tonight at this venue** — `community_events` where `business_id = this` and tonight/upcoming.
2. **Open now** — reuse `business_open_sessions` (food trucks already do this).
3. Keep Follow / Message.
4. Hide or de-emphasize beauty-oriented modules.

### 10.2 What venues get if they pay (do not implement checkout in this spec)

Documented so Growth copy can be rewritten later. Flags stay OFF.

| Plan | Price (existing catalog) | Nightlife-relevant entitlements |
|------|--------------------------|----------------------------------|
| Free | $0 | Basic profile, one upcoming event, appear in Explore |
| Verified | `business_verified` $9.99/mo | Badge, pin on LIVE map, Open Now, listed in Tonight venue row |
| Pro | `business_pro` $29.99/mo | Featured Tonight slot, boost credits, simple "how many viewed / going" (only ship numbers that are real — Growth screen still has placeholders) |

Do not sell Pro analytics until numbers are real (`docs/MONETIZATION_ARCHITECTURE_AUDIT.md`).

Boosts: reuse `post_promotions` / `PostBoostService` for **event and venue posts in Tonight**, not generic feed ads first.

---

## 11. Inbox and communication

### 11.1 Current

`MessagingShellScreen` is a full-screen stacked route with Messages | Events modes, encrypted conversations including event chats (`event_conversation_page.dart`).

### 11.2 v1 (no new tab yet)

- After Going, prompt once: "Open the event chat" (use existing growth-prompt catalog if it fits; there is already a "Going somewhere?" prompt).
- Event detail Chat button stays primary.
- Scene hub: Chat CTA opens the hub/group conversation if one exists.

### 11.3 Phase 2

Promote `MessagingShellScreen` to the INBOX tab. Default landing mode: Events if the user has a happening-now event, else Messages.

Do not add a third chat product.

---

## 12. Notifications (support the loop)

Existing: `activity_notifications` + `ActivityNotificationsService`.

Add types (payload JSON, no new table):

| Type | When | Copy |
|------|------|------|
| `friend_going` | Followed user sets attending | "{name} is going to {event} tonight" |
| `event_starting` | 60 min before `starts_at` if user is attending | "{event} starts in 1 hour" |
| `event_heating` | Heat crosses HOT and user follows event or is attending | "{event} is heating up" |
| `scene_night` | Scene posts a new approved event | "New night in {scene}" |

LIVE nearby notify (`live_nearby_notify_log`) can wait until Tonight has density.

Throttle: max one `friend_going` per event per actor per day; batch "3 people you follow are going" if count ≥ 3.

---

## 13. Create flow (center button, later)

Do not add a new composer stack. Route existing screens:

| Action | Screen |
|--------|--------|
| Post a VUE | `create_post_screen.dart` (destination vue / feed_and_vue) |
| Create a night | `edit_event_screen.dart` (organizer gate unchanged) |
| I'm Here | Event detail — only if user is near / already on the event |

Phase 0–1: keep Event Planner in Settings. Add a Tonight empty-state button that pushes the planner.

---

## 14. Monetization order (when you are ready)

Flags in `lib/config/feature_flags.dart` — do not flip in this track.

| Order | Flag | Who pays | FirstVue job |
|-------|------|----------|--------------|
| 1 | `businessSubscriptionsEnabled` | Venues | Be visible on Tonight / map |
| 2 | `businessBoostsEnabled` | Organizers / venues | Featured Tonight card |
| 3 | `ticketingEnabled` | Guests (platform fee) | Paid Going / cover — **new UX, large** |
| 4 | `vueBountiesEnabled` + `bountyFundingEnabled` | Brands | Pay creators to cover a night |
| 5 | `creatorPayoutsEnabled` | — | Withdrawals after 3–4 work |

**Ticketing v1 (when you get there):** one paid tier on an event (cover or VIP), Stripe Checkout like subscriptions, capacity integer, no door scanner yet. RSVP stays free. Do not build table/bottle deposits until paid Going works.

Free forever (already documented): account, post, discover, message, join scenes, free event create with approval.

---

## 15. Copy, store, and age

### 15.1 Store listing (`docs/STORE_LISTING_DRAFT.md`)

Replace beauty-led short description. Draft:

**Short (≤80):** See what's live tonight. Find your scene. Show up.

**Full:** FirstVue helps you see what's happening tonight, connect with your scene, and discover venues and events in your city.

- Tonight: live events, open venues, what's heating up  
- Scenes: communities around music, nightlife, and local culture  
- Going: RSVP and see when people you follow are going  
- VUE: share the night  
- Venues and organizers: get on the map  

Payments remain off until you flip flags.

### 15.2 Age

Listing currently says 13+. Nightlife as the wedge implies **17+ store rating** and in-app **18+/21+ labels on venues and events**, not a hard ID gate in v1.

Add nullable `age_restriction` on `community_events` and show a badge ("21+") when set. Do not block RSVP in v1.

### 15.3 Onboarding / tutorial

`showFirstLaunchExperience` + `TutorialSection.vue` should explain Tonight: city, Right Now, Going, map. Do not lead with mosaic VUE.

Growth prompts (`growth_prompt_catalog.dart`): keep "Going somewhere?" and add "Join a scene in your city" / "Invite someone to tonight."

---

## 16. City strategy (product, not just code)

Tonight dies if the city is empty.

- Pick **one launch city** (from user prefs — do not hardcode in `LiveHomeService`).
- Seed real approved events and nightlife businesses for that city. No `proto-*` on LIVE.
- Apply `supabase/LIVE_APPLY_ONCE.sql` if realtime / heat / open sessions are not live yet.
- Scenes: 5–15 seeded hubs with real names, not "Test Community."
- Venue outreach: Verified is the first paid conversation, not ads.

Empty-state quality (section 5.5) matters more than nationwide Explore.

---

## 17. Feature flags for this track

Add compile-time flags (default ON for the UX work, so you can disable in a beauty-led build):

```
FIRSTVUE_TONIGHT_DEFAULT_LIVE   // default LiveModePreference to live
FIRSTVUE_FRIENDS_GOING          // RPC-backed friends row
FIRSTVUE_EVENT_DEEP_LINKS       // already should be always on once fixed
FIRSTVUE_SCENES_COPY            // hub/group copy as Scene/Crew
```

Do not add a flag for deep links — that is a bugfix.

Keep money flags OFF.

---

## 18. Implementation phases

### Phase 0 — Unblock the loop (ship first)

1. Event deep links (`deep_link_service.dart`, `main.dart`).
2. Default new installs to LIVE.
3. Add `communityId` to `CommunityEvent` + select lists.
4. Tonight empty state + "Coming up" if Right Now is empty.
5. Store listing + tutorial copy.

**Acceptance:** Shared `?event=` opens event detail. Fresh install lands on LIVE Home. No proto events as social proof.

### Phase 1 — Tonight + friends

1. `event_friends_going` + batch RPC + `EventFriendsService`.
2. Friends row on `LiveRightNowCard` and `LiveEventDetailScreen`.
3. `fetchTonightEvents` section on `LiveHomeShellScreen`.
4. Venue block on event detail when `businessId` is set.
5. Scene chip when `communityId` is set.
6. `friend_going` notification type.

**Acceptance:** If you follow someone who tapped Going, you see them on the card and get one notification.

### Phase 2 — Scenes UX

1. Copy: Scene / Crew / Start a scene.
2. Hub detail: Tonight-in-this-scene section.
3. Explore order: Scenes, Tonight, Bars first.
4. Invite button → share + message picker.
5. Optional: relabel LIVE switch to TONIGHT.

**Acceptance:** A hub shows its crews' nights. Explore leads with scenes and tonight.

### Phase 3 — Nav + inbox (only after density)

1. Consider TONIGHT | SCENES | CREATE | INBOX | PROFILE.
2. Promote messaging shell to a tab.
3. Create sheet: VUE / Night / I'm Here.

**Acceptance:** First-time user can complete the north-star loop without opening Settings.

### Phase 4 — Monetize visibility

1. Rewrite `business_growth_screen.dart` copy for venues (Tonight pin, Open Now, featured).
2. Flip subscription/boost flags when Stripe is ready.
3. Featured Tonight placement using existing promotions table.

### Phase 5 — Paid Going (separate project)

Ticketing v1. Out of scope until Phase 4 is real.

---

## 19. File checklist

### Must touch (Phase 0–1)

| File | Why |
|------|-----|
| `lib/services/deep_link_service.dart` | `?event=` |
| `lib/main.dart` | Open event detail from deep link |
| `lib/services/live_mode_preference.dart` | Default LIVE for unset prefs |
| `lib/services/things_to_do_service.dart` | `communityId`, `fetchEventById`, tonight query |
| `lib/services/live_home_service.dart` | Tonight section + friends batch |
| `lib/screens/live_home_shell_screen.dart` | Layout sections + empty state |
| `lib/widgets/live/live_right_now_card.dart` | Friends-going line |
| `lib/screens/live_event_detail_screen.dart` | Friends, venue, scene, invite |
| `lib/services/event_friends_service.dart` | New |
| `supabase/migrations/*_event_friends_going.sql` | New RPC |
| `docs/STORE_LISTING_DRAFT.md` | Positioning |
| `test/vue_landing_test.dart` | Default mode |
| `test/live_mode_shell_test.dart` | Default mode |
| New deep-link + friends-going tests | Regressions |

### Phase 2

| File | Why |
|------|-----|
| `lib/screens/community_hub_detail_screen.dart` | Tonight-in-scene |
| `lib/screens/communities_screen.dart` | Scene copy |
| `lib/screens/create_community_screen.dart` | Start a scene |
| `lib/screens/explore_screen.dart` + `explore_feed_service.dart` | Section order |
| `lib/widgets/vue_live_mode_switch.dart` | TONIGHT label |
| `lib/services/growth_prompt_catalog.dart` | Scene / invite prompts |

### Do not touch unless Phase 4–5

- Stripe edge functions
- `FeatureFlags.ticketingEnabled`
- Beauty / rental schemas
- New chat protocol

---

## 20. Tests

- Deep link: `?event=` → target type `event`.
- `LiveModePreference.parse(null)` → `live` after Phase 0; saved `vue` still `vue`.
- Friends RPC: returns only followed attending profiles; never non-followed.
- Tonight query: excludes ended and `proto-*`.
- Existing LIVE tests keep passing (`test/live_mode_shell_test.dart`).
- `CommunityEvent` serialization includes `communityId` when present.

---

## 21. Success metrics (instrument with existing `product_events`)

| Signal | Meaning |
|--------|---------|
| Tonight land rate | % of sessions whose first tab is LIVE/Tonight |
| Event open from Tonight | Card tap-through |
| Going conversion | Opens → attending |
| Friends-going impression → Going | Social proof working |
| Event share open (`?event=`) | Loop works outside the app |
| Scene join from event chip | Community forming |
| Venue profile from event | Business visibility |

Do not optimize FEEDS time-spent as a north-star metric for this track.

---

## 22. Risks

| Risk | Mitigation |
|------|------------|
| Empty Tonight in a new city | Empty state + 7-day Coming up + one-city seeding |
| Nav reshape too early | Phase 0–1 keep five tabs |
| Public guest-list creepy | Friends-going RPC only |
| Dual RSVP systems diverge | Going = `attending`; one write path |
| Selling fake analytics | Keep Growth placeholders off paid claims |
| 13+ vs nightlife | Store rating + 21+ badge, not ID scan |
| Scope creep (ticketing, streaming, tables) | Phases 4–5 only |

---

## 23. Suggested first implementation PR (when you start coding)

Single PR, Phase 0 only:

1. Event deep links + `fetchEventById`
2. Default LIVE for new installs
3. `communityId` on `CommunityEvent`
4. Tonight empty / coming-up state
5. Tests

Phase 1 (friends + tonight strip) is the second PR. Do not combine with nav rename.
