# FirstVue Web Messaging Architecture (Phase 1)

This document is the implementation contract for the unified web messaging
product. Legacy 1:1 plaintext DMs remain in place until active-conversation
migration is verified. New conversations use this schema only.

## Current system (inspected)

| Area | Location | Notes |
| --- | --- | --- |
| Inbox UI | `lib/screens/messages_inbox_screen.dart` | Primary / Unread / Archived / Saved |
| Thread UI | `lib/screens/conversation_screen.dart` | Plaintext bubbles + Realtime inserts |
| Compose | `lib/screens/new_message_screen.dart` | Profile + business-owner search |
| Service | `lib/services/messaging_service.dart` | `direct_message_threads` / `direct_messages` |
| Unread RPC | `unread_direct_message_count()` | Security definer |
| Reactions | `direct_message_reactions` | Unicode emoji, not encrypted |
| Media | `direct_messages.media_path` | Optional, unencrypted |
| Entry | Floating bubble, settings, profiles, rentals | Opens inbox / conversation |

Gaps versus the approved product at inspection: no identity switching, no
message requests, no entity shared inbox, no event chats, no E2EE, no
blocks across identities, no parental controls, no calls.

The web messaging implementation now lives in `lib/messaging/` with
additive SQL `20260915_fv_web_messaging.sql`. See
`docs/MESSAGING_COMPLETION.md` for the completion report.

## Parallel data model

New tables are prefixed `fv_msg_*` so legacy DMs are untouched.

- `fv_msg_conversations` — direct / group / community / entity_inbox / event
- `fv_msg_members` — profile + posting identity + mute / read cursor
- `fv_msg_devices` — per-device X25519 public keys only
- `fv_msg_key_envelopes` — conversation-epoch keys wrapped to device public keys
- `fv_msg_messages` — ciphertext + nonce + metadata (never plaintext)
- `fv_msg_revisions` — edit history (ciphertext)
- `fv_msg_attachments` — encrypted object paths
- `fv_msg_reactions` — encrypted reaction payloads
- `fv_msg_internal_notes` — entity-staff-only ciphertext
- `fv_msg_assignments` / tags / status on entity conversations
- `fv_msg_event_settings` / channels / plans
- `fv_msg_blocks` — account-level (all identities)
- `fv_msg_reports` — reporter-selected ciphertext bundles
- `fv_msg_parental` / approved contacts
- `fv_msg_recovery` — wrapped master key, never plaintext secrets
- `fv_msg_migration` — restartable legacy import

## Encryption protocol

**Selected protocol:** Envelope encryption with X25519 + HKDF-SHA256 +
AES-256-GCM (`package:cryptography`, which uses Web Crypto on Flutter web).

This is not a custom cipher. It is a documented composition of:

1. **Device identity:** X25519 keypair per browser/device.
2. **Conversation secret:** 256-bit random key per epoch.
3. **Key wrapping:** X25519 ECDH with the recipient device public key,
   HKDF-SHA256 (`fv-msg-wrap-v1`), AES-256-GCM wrap of the conversation secret.
4. **Message encryption:** AES-256-GCM with a per-message key derived as
   `HKDF(conversation_secret, info = "fv-msg-msg-v1" || message_id)`.
5. **Media:** file bytes encrypted with a random content key; content key
   wrapped by the conversation secret and stored in attachment metadata.
6. **Groups / events / entity inboxes:** same conversation secret, wrapped to
   every authorized member device. Membership change increments `epoch` and
   rotates the conversation secret. New authorized members receive the
   *current history epoch* wrap so they can read permitted prior history
   without the server seeing plaintext.
7. **Revocation:** leaving members stop receiving new envelopes. FirstVue
   clears its local cache for that conversation on next connect. Already
   viewed content on the lost device cannot be remotely erased
   (screenshots, copies, and OS backups are out of scope).
8. **Internal notes:** separate note-epoch key wrapped only to entity team
   devices with messaging permission — never to customers.
9. **Recovery:** optional passphrase (Argon2id / PBKDF2-HMAC-SHA256 on web)
   wraps the device private key. Trusted-device transfer exports a wrapped
   blob. Recovery secrets are never stored in plaintext columns.
10. **Reporting:** reporter decrypts locally and uploads a *selected-message
    bundle* (ciphertext of the report package encrypted to a FirstVue
    moderator public key). Moderators never get inbox-wide keys.

### Why not OpenMLS in this web release

OpenMLS (RFC 9420) remains the recommended long-term group protocol for a
future native app. Flutter web cannot currently ship a maintained OpenMLS
binding without a custom WASM stack and security review. The envelope model
above is the web-compatible, well-reviewed primitive set, with a `protocol`
column (`envelope-v1`) so MLS can be added later without rewriting rows.

### Threat model (honest)

| In scope | Out of scope |
| --- | --- |
| Server cannot read message bodies or media | Compromised client / malware |
| Honest-but-curious Supabase operators | Screenshots, shoulder surfing |
| Network observers | Forced key disclosure by a user |
| Unauthorized identity switching via RLS | Metadata: membership, timestamps, sizes |
| Removed members receiving *future* epochs | Deleting content already decrypted locally |

Metadata (who talked, when, attachment sizes) is visible to the server.
Notifications never include plaintext bodies.

### Trusted migration boundary

Active legacy threads (activity in the last 90 days, or explicitly retained)
are encrypted on the **signed-in participant’s device** during migration.
Plaintext is read from `direct_messages`, encrypted, written to
`fv_msg_messages`, then the migration row is marked `encrypted`. Temporary
plaintext exists only in RAM on that device. Legacy rows are **not deleted**
until an operator confirms counts.

## Identity and permissions

Personal identity is default. Entity identities come from
`businesses.created_by` and `business_memberships` where
`has_messaging_permission` is true:

- Allowed: `owner`, `manager`, `moderator`
- Denied: `analytics_viewer`, `content_editor` / `staff` (no messaging)

Switching identity filters conversations; it never mixes personal DMs with
entity customer threads.

## Event chat

Created only when the host enables chat (`fv_msg_event_settings.chat_enabled`).
Default channels: Announcements + Attendee chat. Optional topic channels.
Plans are ciphertext cards, not check-ins. Archive stops inserts.

## Calls

WebRTC (`flutter_webrtc`) for **1:1 personal** conversations only. Signaling
rows in `fv_msg_calls` contain SDP/ICE, not media. Unsupported browsers show
an explicit state. No group / community / event / entity-inbox calls.

## RLS rules

- Enable RLS on every `fv_msg_*` table.
- Membership helpers are `security definer`, `stable`, boolean-only,
  `search_path = public`, granted to `authenticated` only.
- Clients cannot insert privileged member roles.
- Blocks apply to all conversation kinds.
- Under-13: only parent-approved contacts.
- Storage bucket `fv-msg-media` is private; objects are encrypted blobs.
