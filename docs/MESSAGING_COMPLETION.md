# FirstVue web messaging — completion report

This branch implements the unified web messaging product as a parallel
system beside legacy plaintext DMs. Legacy tables are not dropped.

## Architecture summary

One full-screen destination (`MessagingShellScreen`) hosts Messages and
Events. Identity switching filters inboxes. Personal 1:1, entity shared
inbox, and event conversations share the same E2EE envelope protocol.

**Protocol `envelope-v1`:** X25519 device keys + HKDF-SHA256 + AES-256-GCM
(`package:cryptography` / Web Crypto on Flutter web). Conversation secrets
are wrapped to each authorized device. Media is encrypted before upload to
`fv-msg-media`. The server stores ciphertext, nonces, membership, and
metadata only.

**Why not OpenMLS yet:** no maintained Flutter-web binding. The `protocol`
column allows MLS later.

**Threat model (honest):** the server cannot read bodies or media.
Membership, timestamps, and sizes are visible. Screenshots, copies, and
OS backups cannot be remotely erased. Device private keys on web live in
origin storage (not hardware-backed); users should set a recovery
passphrase.

**Legacy:** `direct_message_*` remains. New UI falls back to those rows
when `fv_msg_*` is not applied. Migration encrypts active threads
(90-day activity) on-device and records `fv_msg_migration` without
deleting the source.

## SQL migrations

`supabase/migrations/20260915_fv_web_messaging.sql`

- Tables: conversations, members, devices, key envelopes, messages,
  revisions, attachments, reactions, local deletes, internal notes,
  assignments, tags, saved replies, event settings/channels/plans,
  notification prefs, indicator prefs, parental + approved contacts,
  blocks, reports, calls, audit, rate events, recovery, moderator keys,
  migration.
- RLS enabled on every table. Membership helpers are security-definer
  boolean functions (`fv_msg_is_member`, `fv_msg_can_access`) to avoid
  recursive policies.
- RPCs: `fv_msg_open_direct`, `fv_msg_open_entity_inbox`,
  `fv_msg_enable_event_chat` (uses `community_events.organizer_id`),
  `fv_msg_join_event_chat`, `fv_msg_archive_event_chat`,
  `fv_msg_next_seq`, `fv_msg_unread_counts`, `fv_msg_mark_read`,
  `fv_msg_within_rate_limit`, `fv_msg_contact_allowed`.
- Storage bucket `fv-msg-media` (private, encrypted blobs; first path
  segment is conversation UUID).

**Not applied to the remote project from this environment.** Supabase MCP
is unauthenticated (`needsAuth`). Apply the migration in the FirstVue
Supabase project, then verify with a signed-in owner, manager, customer,
under-13 child, and blocked pair.

## Encryption / recovery

- Device X25519 keypair via `DeviceKeystore` (SharedPreferences).
- Epoch wrap to member devices; `wrapHistoryForProfiles` for new members;
  `rotateConversationKeys` on membership loss.
- Recovery passphrase: PBKDF2-HMAC-SHA256 (150k) wrapping the private key
  into `fv_msg_recovery`.
- Reports: reporter-selected messages only, encrypted bundle in
  `fv_msg_reports`. Moderators never receive inbox-wide keys.
- Optional on-device search flag; server search is titles/handles only.

## Tests

```
flutter test test/fv_messaging_test.dart test/messaging_gallery_test.dart
```

Crypto, identity cards, event rows, and a four-screen gallery capture
matching the approved mockups.

## Screenshots

Layout fixtures (not production data) with Inter + Material Icons.
Custom SpaceGrotesk files are not in the repo (OFL only).

There is no 1:1 private-chat mockup and no desktop entity-inbox mockup in
the four approved PNGs. Those surfaces still exist in the product.

| Screen | File | Size |
| --- | --- | --- |
| Unified Messages (All + event section) | `/opt/cursor/artifacts/screenshots/01-unified-messages.png` | 390×844 @1.5 |
| Event conversation (attendee chat) | `/opt/cursor/artifacts/screenshots/02-event-conversation.png` | 390×844 @1.5 |
| Unified Events hub | `/opt/cursor/artifacts/screenshots/03-unified-events.png` | 390×844 @1.5 |
| Unified Messages inbox | `/opt/cursor/artifacts/screenshots/04-unified-messages-inbox.png` | 390×844 @1.5 |

## Migration results

Not run against live data. `FvMessagingService.migrateActiveLegacy()` is
restartable, skip-if-exists via `legacy_thread_id`, writes status
`encrypted` / `failed`, and does not delete `direct_messages`.

## Performance checks

- Cursor-style message fetch: last 80 by `created_at desc`
- Debounced search (280ms)
- Unread aggregation RPC (not per-row client loops for counts)
- Realtime channel unsubscribe on dispose
- Remaining: assignment labels are still per-conversation (N+1) in inbox
  hydration; batch in a follow-up after the migration is applied

## Remaining risks / unsupported

- **Apply SQL** before encrypted send/media/calls work in production.
- WebRTC: Chrome / Edge / Safari with mic/camera permission. Linux widget
  tests skip session start. No global incoming-call overlay yet.
- Composer currently encrypts **text + gallery images**. Schema accepts
  video, voice, files, GIF, sticker, contact, location, event/post cards;
  those pickers are not all wired.
- Device private key is origin storage, not hardware-backed.
- Incoming-call listen + device picker are incomplete.
- Local search is an opt-in flag, not a full encrypted inverted index.
- Report bundles are not yet wrapped to `fv_msg_moderator_keys` when empty.
- Under-13 enforcement is RPC-side (`birthday` + approved contacts); UI
  for approving contacts is settings-only.
- Layout follows the four approved mockups: unified Messages, event
  attendee chat, Events hub, and the Messages inbox with Messages/Events tabs.
- Do not delete legacy DMs until an operator verifies migrated counts.

## Changed files (high level)

- `docs/MESSAGING_ARCHITECTURE.md`
- `supabase/migrations/20260915_fv_web_messaging.sql`
- `lib/messaging/**`
- `lib/screens/messages_inbox_screen.dart` (wrapper)
- Profile / rentals / notifications / share / meet-the-owner entry points
- `lib/config/media_config.dart` (`fv-msg-media`)
- `pubspec.yaml` (`cryptography`, `flutter_webrtc`, `uuid`)
- `test/fv_messaging_test.dart`, `test/messaging_gallery_test.dart`
