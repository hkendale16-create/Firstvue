# Phase 0 — FirstVue Web Messaging Inspection Report

**Status:** Inspection only. No schema, RLS, client, or data changes in this phase.  
**Branch:** `cursor/messaging-phase0-inspection-fa96`  
**Date:** 2026-08-14  
**Live Supabase MCP:** Not authenticated for this agent run — schema findings are from committed migrations and Flutter clients. Live row counts / dry-run migration stats require Supabase MCP auth before Phase 1/7.

---

## 1. Current messaging / event architecture

### What exists today

FirstVue has a **1:1 plaintext DM system**, not a multi-type conversation platform.

| Layer | Reality |
| --- | --- |
| Conversation model | `direct_message_threads` with exactly two profile participants (`participant_a`, `participant_b`) |
| Messages | `direct_messages` plaintext `body` (1–2000 chars); optional unused `media_path` / `reply_to_id` |
| Read state | `direct_thread_reads` (`last_read_at`, `archived_at`, `saved_at`) per user/thread |
| Reactions | `direct_message_reactions` (schema ahead of full UI usage) |
| Identity | Always `auth.uid()` personal profile. No send-as-entity for chat |
| Group / community / event chat | **Absent** |
| Message requests | **Absent** (first contact goes straight into inbox) |
| Blocks / mute | **Absent** for messaging |
| E2EE | **Absent** — bodies stored and transported as plaintext |
| Chat Storage bucket | **Absent** despite `media_path` column |
| Calling | **Absent** |
| Child / parental messaging gates | **Absent** |

### Relevant Flutter files

**Core**
- `lib/services/messaging_service.dart` — models + CRUD/RPC
- `lib/screens/messages_inbox_screen.dart`
- `lib/screens/conversation_screen.dart`
- `lib/screens/new_message_screen.dart`
- `lib/widgets/floating_messages_bubble.dart`

**Entry points**
- `lib/main.dart` (home-tab floating bubble)
- `lib/widgets/firstvue_settings_drawer.dart`
- `lib/screens/notifications_screen.dart`
- `lib/widgets/firstvue_share_sheet.dart`
- Profile/business/owner/rental/story CTAs under `lib/screens/`

**Notifications (separate from DM unread)**
- `lib/services/activity_notifications_service.dart`
- `lib/services/notification_service.dart` (local notifications only; no FCM/APNs device tokens)
- `lib/services/user_preferences_service.dart` (`push_messages`, `show_floating_messages`)

**Events (source of truth for Phase 5 linkage)**
- `lib/services/things_to_do_service.dart` (`CommunityEvent`)
- `lib/services/event_social_service.dart` (follow + RSVP)
- `lib/services/event_media_service.dart`
- `lib/screens/things_to_do_screen.dart`
- `lib/screens/whats_now_screen.dart` (“What’s Now” — not a shared Happening Now ranking service)
- `lib/services/live_stream_service.dart` (eligibility only; no broadcast)

**Identity / roles (reusable, not wired to chat)**
- `lib/models/post_identity.dart` + `post_identity_service.dart` (feed posting only)
- `business_memberships` roles: owner / manager / content_editor / moderator / analytics_viewer
- Community/hub leadership in `community_service.dart` / `community_hub_service.dart`

### Routing

Imperative `Navigator.push` only. No named messaging routes or deep links for threads (`DeepLinkService` supports business/profile/post only).

---

## 2. Existing database objects (from migrations)

### Tables

| Object | Migration | Notes |
| --- | --- | --- |
| `direct_message_threads` | `20260811_messaging_and_comments.sql` | Unique pair index; optional `business_id` |
| `direct_messages` | `20260811` + media/reply in `20260905_social_ux_stories_messenger.sql` | Plaintext body |
| `direct_thread_reads` | `20260905_…` | Per-user read/archive/save |
| `direct_message_reactions` | `20260905_…` | `(message_id, user_id)` |
| `activity_notifications` | `20260812_explore_social_features.sql` | SELECT/UPDATE only — **no INSERT policy** |
| `user_preferences` | `20260821_social_platform_upgrade.sql` | Includes `push_messages`, `show_floating_messages` |
| `notification_subscriptions` | `20260821_…` | Schema present; **unused in Dart** |
| `email_outbox` | `20260811_phase3_aws_notifications.sql` | SES path |
| `community_events` | `20260812_explore_social_features.sql` | App uses `event_at` |
| `event_follows` / `event_attendance` | `20260821_…` | RSVP + follow |
| `community_organizers` / applications | `20260812` / `20260813` | Host gate |
| `live_stream_eligibility` | `20260821_…` | Not live activity policy catalog |
| `business_specials` | `20260813_menus_news_feed.sql` | Menu specials, not Happening Now |

**No tables for:** conversation types, multi-participant memberships, message requests, blocks, entity inbox assignments, event channels, device/key metadata, encrypted envelopes, live-activity policy config, parental consent.

### RPCs / functions

- `search_message_recipients` — `20260816_rental_admin_and_message_search.sql`
- `unread_direct_message_count()` — security definer, participant-scoped — `20260905_…`
- `mark_direct_thread_read(p_thread_id)` — `20260905_…`
- `refresh_live_eligibility` — live stream eligibility only

### Storage buckets

Existing private-ish media buckets (`profile-media`, `business-media`, `community-news-media`, `rental-media`, `stories`, …). **No `message-media` / chat attachments bucket or policies.**

### Realtime

Client subscriptions:
- `conversation_screen.dart` → Postgres Changes on `direct_messages` (`dm-{threadId}`)
- `activity_notifications_service.dart` → `activity_notifications`
- Feed screens → `community_news_posts` / `feed_comments`

**Gap:** migrations add feed tables to `supabase_realtime` publication; **no migration adds `direct_messages` or `activity_notifications`**. Conversation realtime may fail silently depending on dashboard-only publication config (undocumented).

### RLS themes (current DMs)

- Thread/message access iff `auth.uid()` is participant_a or participant_b
- Send requires `sender_id = auth.uid()` + participant membership
- Read prefs/reactions own-row + participant checks
- **Does not** support entity team shared inbox, multi-member rooms, or request gating

---

## 3. Stuck unread badge — root causes

Multiple independent bugs create stale / false unread UI. Fixing only the bubble will not meet acceptance criteria.

### Root cause A — Notifications hard-codes unread (definite bug)

`lib/screens/notifications_screen.dart` Message preview tiles set:

```dart
unread: true,  // ignores thread.isUnread
```

Every DM preview on Notifications always appears unread.

### Root cause B — Floating bubble never reconciles

`lib/widgets/floating_messages_bubble.dart`:
- Loads unread once in `initState` and after returning from inbox
- Exposes `refresh()` but `main.dart` creates `GlobalKey<FloatingMessagesBubbleState> _messagesBubbleKey` and **never calls** `currentState?.refresh()`
- No Realtime / Presence / Broadcast subscription for new DMs on the bubble
- Bubble only mounts on home tab (`selectedIndex == 0`)

### Root cause C — Error fallback invents unread

`MessagingService._countUnread` returns **`1` on any query error**, which can inflate inbox/fallback totals and leave a sticky “1”.

### Root cause D — Dual unread systems

- Chat badge → `MessagingService.unreadCount()` / `unread_direct_message_count`
- Home avatar badge → `ActivityNotificationsService.unreadCount()` on `activity_notifications`
- `sendMessage` does **not** write `activity_notifications` of type `direct_message`, so activity-channel message alerts are largely unused for DMs

### Root cause E — No durable per-identity cursor model for product goals

Current cursors are personal-profile only (`direct_thread_reads.user_id`). Product requires per personal/entity identity unread totals plus combined reconciliation. Schema cannot express that yet.

**Conclusion:** The stuck badge is not a single UI glitch. Phase 3 must replace hard-coded flags, error fallbacks, and one-shot bubble loads with durable per-identity read cursors + reconnect reconciliation. Phase 1 must introduce that foundation before UI polish.

---

## 4. Conflicts, duplicates, security, and migration risks

| Risk | Severity | Notes |
| --- | --- | --- |
| Plaintext historical DMs cannot become true historical E2EE without clients | High | Must not relabel migrated bodies as E2EE. Prefer legacy read-only archive + new encrypted conversations, or client-assisted encryption later |
| Duplicate / parallel conversation models | High | Do not extend `direct_message_threads` into groups. Introduce a new canonical conversation model; dual-read during migration |
| `community_events` shape drift | Medium | `20260821` IF NOT EXISTS alternate columns vs live `event_at` used by app — inspect live DB before event-channel FKs |
| Activity notification INSERT RLS missing | Medium | Client inserts fail closed (swallowed); email/outbox path separate |
| Realtime publication undocumented for DMs | Medium | Scale design should move to Broadcast anyway (product requirement) |
| Optional `business_id` on threads ≠ entity inbox | Medium | Current “message business” is user↔owner personal DM with a label |
| Schema ahead of client (media, reply, reactions, hide_read_receipts) | Low–Medium | Columns unused / partially used — migration must not assume client parity |
| AGPL Matrix SDK if chosen for E2EE | Legal | May conflict with proprietary FirstVue distribution — evaluate before adopting |
| Under-13 messaging absent | Compliance | Keep disabled via server feature flag until Phase 6 + legal review |
| No user_blocks table | Security | Identity switching could evade blocks unless account-level blocks land early |
| Service-role leakage | Security | No evidence of service-role in Flutter; keep it that way. Privileged work in Edge Functions only |
| Live Supabase not inspectable this run | Process | Row counts / quarantine dry-runs blocked until MCP auth |

### Proposed “active conversation” definition (for Phase 7 — not applied now)

A conversation is **active** if **all** hold:

1. Thread row exists with two distinct non-deleted profiles (or future multi-member set with ≥1 active membership).
2. At least one message in the last **180 days**, **or** any participant opened/read it in the last **90 days** (`last_message_at` / `last_read_at`).
3. Both participants still exist and are not permanently deleted.
4. For legacy 1:1 only: `participant_a` / `participant_b` satisfy the unique pair constraint.

Everything else → **quarantine** with reason codes (`orphan_participant`, `empty_never_opened`, `corrupt_pair`, `missing_message_fk`, …), aggregate counts only, no plaintext in logs.

---

## 5. E2EE options comparison and recommendation

Product forbids hand-rolled crypto. Requirement: browser + 1:1 + groups + multi-device + membership changes + key rotation + encrypted attachments + history sharing + recovery.

| Option | Protocol | Browser | Groups / membership | Maintenance | Fit for FirstVue |
| --- | --- | --- | --- | --- | --- |
| **OpenMLS (`openmls` / openmls_dart)** | IETF MLS (RFC 9420), TreeKEM | WASM via dart2js Flutter web | Designed for scalable groups, add/remove, forward secrecy | Rust OpenMLS is actively maintained; Dart bindings newer — treat as POC risk | **Best protocol fit** for entity/community/event rooms |
| **Matrix Dart SDK + Vodozemac** | Olm/Megolm | Supported (WASM Vodozemac) | Mature rooms, but couples to Matrix event model / often a homeserver | Mature (Famedly) | Strong crypto maturity; **AGPL-3.0** and Matrix semantics are heavy for embedding inside FirstVue identity |
| **libsignal / Signal Protocol** | X3DH + Double Ratchet (+ sender keys) | Official Flutter-web story weak; custom WASM/FFI likely | Excellent 1:1; groups historically weaker than MLS | Signal maintains native libs | Good for 1:1 only; incomplete for FirstVue group/community/event scope without MLS anyway |
| **Custom protocol** | — | — | — | — | **Forbidden** |

### Recommendation (Phase 0 decision for review)

1. **Adopt MLS (OpenMLS) behind a FirstVue-owned `MessagingCrypto` interface** — envelopes, devices, attachments, recovery stay FirstVue-shaped; crypto library is swappable.
2. **Do not enable E2EE in production** until a qualified security review passes (product rule).
3. **Phase 2 POC** must prove: 1:1 + small group, multi-device, membership rotation, encrypted attachment upload/download, selected-message report export, local encrypted search index, PIN backup + recovery key + device transfer.
4. **Fallback contingency:** if OpenMLS Flutter-web bindings fail POC acceptance, evaluate Vodozemac **as a crypto engine only** (not a Matrix homeserver), with legal review of licensing — still no custom crypto.
5. **Legacy plaintext:** keep as clearly labeled non-E2EE archive; new sends use encrypted envelopes only after Phase 2/3 gate.

Recovery UX (product-required): PIN-protected encrypted cloud backup, authorized device transfer, user-held recovery key — all designed in Phase 2, not Phase 1.

---

## 6. Target architecture notes (non-destructive)

```
Client (Flutter web)
  ├─ Messaging UI (full-screen route)
  ├─ MessagingRepository (idempotent send, offline queue)
  ├─ MessagingCrypto (OpenMLS / reviewed lib)
  └─ RealtimeTransport (Supabase Broadcast + Presence)
        ↓
Supabase
  ├─ Auth (canonical account)
  ├─ Postgres (metadata, encrypted envelopes, cursors, policies)
  ├─ Private Storage (encrypted attachments)
  ├─ Edge Functions (privileged ops only; never plaintext)
  └─ Realtime Broadcast (delivery hints; DB is source of truth)
```

**Happening Now:** one server-side eligibility/ranking service + admin-editable policy table; Home / Explore / Events / Messaging / city pages consume the same API. Do not fork filters per screen.

**Event chat:** FK to existing `community_events` (or successor canonical event id); do not duplicate schedule/RSVP/privacy.

---

## 7. Exact Phase 1 scope (proposed — awaiting review)

### Goal

Secure data + authorization foundation only. **No** legacy data migration, **no** E2EE enablement, **no** full UI rewrite, **no** Happening Now ranking, **no** under-13 messaging.

### Proposed new migration(s)

`supabase/migrations/20260915_messaging_foundation.sql` (name may adjust after live inspect):

Additive, idempotent objects (draft list for review):

1. `messaging_identities` view or table mapping account → personal profile + authorized entity actors  
2. `conversations` (type enum: `direct`, `private_group`, `entity_inbox`, `community_channel`, `event_announcements`, `event_attendee`, `event_topic`)  
3. `conversation_participants` (identity_id, role, muted_until, invited_by, left_at, …)  
4. `conversation_read_cursors` (participant/identity scoped; source of truth for unread)  
5. `message_requests` (first-contact gate)  
6. `account_blocks` (canonical account-level; blocks all identities)  
7. `entity_inbox_assignments` + `entity_inbox_statuses`  
8. `entity_internal_notes` (separate encrypted context later; Phase 1 stores ciphertext-ready envelope columns, no plaintext)  
9. `event_conversation_links` FK → `community_events`  
10. `messaging_devices` / `messaging_device_keys` metadata (no private keys server-side)  
11. `live_activity_policies` + `live_activities` skeleton with admin audit columns  
12. Private Storage bucket `message-attachments` + path policies (`auth.uid()` folder prefix + participant RPC checks)  
13. Strict RLS for every table; security-definer helpers that **cannot** recurse (follow lessons from `20260910_community_rls_recursion_media_delete.sql`)  
14. Feature flags: `messaging_e2ee_enabled` default false; `messaging_under13_enabled` default false  

**Do not drop or rewrite** `direct_message_*` in Phase 1.

### Proposed Flutter files (Phase 1)

| Action | Path |
| --- | --- |
| Add | `lib/services/messaging/messaging_models.dart` |
| Add | `lib/services/messaging/messaging_authz_service.dart` |
| Add | `lib/services/messaging/conversation_repository.dart` (new schema only; dual-read stub) |
| Add | `test/messaging_rls_contract_test.dart` (policy contract / role matrix) |
| Add | `test/messaging_unread_cursor_test.dart` |
| Touch lightly | `lib/services/messaging_service.dart` — document legacy; no behavior break |
| Docs | update this report’s Phase 1 results section after apply |

### Explicitly out of Phase 1

- OpenMLS integration  
- Full-screen Messenger UI  
- Migrating `direct_messages` rows  
- Entity inbox UX  
- Event channels / Happening Now ranking  
- Calling  
- Child messaging enablement  

### Phase 1 test plan

- `dart format` / `flutter analyze`  
- Unit tests for unread cursor math and identity authorization matrices  
- Adversarial RLS tests: outsider, blocked account, former team member, wrong entity role, anon  
- Migration idempotency re-run  
- Confirm legacy DM send/receive still works (no regression)  

### Phase 1 rollback

- Reverse migration that drops only new objects (keep legacy intact)  
- Feature flags remain off  
- Clients on old code paths unaffected  

---

## 8. Risk register (summary)

| ID | Risk | Mitigation |
| --- | --- | --- |
| R1 | Plaintext→E2EE false labeling | Legacy archive labeling; dual-write only after crypto review |
| R2 | OpenMLS Flutter-web immaturity | Phase 2 POC gate; Vodozemac contingency + legal review |
| R3 | RLS recursion (seen before in communities) | Prefer SECURITY DEFINER helpers with fixed search_path; adversarial tests |
| R4 | Unread drift across tabs/devices | Durable cursors + Broadcast hints + reconcile on focus/reconnect |
| R5 | Event table column drift | Live inspect before `event_conversation_links` |
| R6 | Under-13 premature enable | Server flag default off through Phase 6 |
| R7 | Attachment URL leakage | Private bucket; short-lived authorized URLs; never public |
| R8 | Push plaintext leak | Encrypted envelopes; push payload is opaque/metadata-only |

---

## 9. Rollback / non-change statement for Phase 0

Phase 0 made **no** database, Storage, RLS, or production client behavior changes. This document and PR are review artifacts only.

---

## 10. Blockers before Phase 1 can start safely

1. **Human review** of this report, E2EE recommendation, active-conversation definition, and Phase 1 object list.  
2. **Supabase MCP authentication** (requested for this environment) so we can:  
   - confirm live publication of `direct_messages`  
   - confirm live `community_events` columns  
   - dry-run active conversation counts  
   - apply Phase 1 migrations with verification queries  
3. Agreement that Phase 1 will **add** a parallel foundation rather than mutate legacy DM tables in place.

---

## 11. Proposed next phase after approval

**Phase 1 — Secure data and authorization foundation** as scoped in §7.

Phase 2 (preview only): OpenMLS POC behind `MessagingCrypto`, Broadcast delivery, encrypted attachments, recovery flows — still behind feature flags and security review.
