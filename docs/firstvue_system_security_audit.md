# FirstVue system, Supabase, performance, and security audit

**Phase 1 — read-only.** No Flutter, SQL, RLS, Storage, Auth, Netlify, or production changes were made. No production rows were exported. No secrets are printed here.

**Date:** 2026-08-14  
**Auditor:** Cursor cloud agent (Phase 1 only)  
**Stop condition:** Do not begin Phase 2 until the operator replies `Approved — begin Phase 2.`

---

## Executive summary

### Overall Supabase / code alignment

The live project `sdssshegqdwobjelxzkp` is the application’s configured backend. A publishable-key, row-free table probe (`select … limit 0`) plus RPC `OPTIONS` checks show **most Flutter tables and every Dart-called RPC exist remotely**, including `has_hub_role`, `replace_business_avatar`, `fetch_ranked_main_feed`, and the `fv_msg_*` messaging schema.

Alignment is **not complete**:

- Live PostgREST does **not** expose `feed_interactions` or `community_organizer_applications` (`PGRST205`).
- There are **no generated Dart database types**. Flutter uses hand-written models and defensive column fallbacks (`_selectPosts` retries narrower selects). That hides drift until runtime.
- Local SQL is the intended source of truth (`supabase/migrations/`, 59 files). OpenAPI / `pg_catalog` could not be dumped (secret API key required; Supabase MCP `needsAuth`). RLS policy text on the live catalog was inferred from migrations plus live object presence, not from `pg_policies`.

**Verdict:** Schema and app are largely aligned for core social surfaces. Two live gaps plus RLS-on-PII and plaintext DMs are the blockers, not a wholesale mismatch.

### Confirmed loading bottlenecks

Runtime cold/warm Home and Feeds timings against a **FirstVue Flutter** host were **not measured**. `https://firstvue.app` is a domain lander (not the Flutter shell). `https://firstvue.netlify.app` is an unrelated Vue app titled “first-vue”. Flutter SDK was not present in this environment; Phase 1 did not spend the one allowed release build on a host that cannot represent production UX.

Static request graphs for Home and Feeds are still conclusive:

1. Home useful content is blocked on `TrendingBusinessesService.hasComingSoonBusinesses()` before tabs render.
2. Ranked feed RPC `fetch_ranked_main_feed` does per-post `count(*)` laterals on sparks and comments.
3. Each feed page then runs **~12 sequential hydration queries** in `CommunityNewsService._mapPostRows` (names, usernames, businesses, communities, media, sparks, saves, follows, …), then more for reposts.
4. Video thumbnails construct a full `VideoPlayerController.networkUrl` (full-file download) instead of a poster image.
5. Signed media URLs last **7 days** (`604800` seconds); missing objects will be retried for a week.
6. Home and Feeds each open a Realtime channel on `community_news_posts`. Bottom nav uses a `switch` (only one tab mounted) — good. Feeds `PageView.builder` can still warm adjacent tabs.

### Overall security readiness

**Not safe for a user-intensive social production launch** until emergency RLS/PII and messaging-at-rest issues are repaired. Core tables have RLS enabled in migrations. Admin self-escalation is blocked by trigger + JWT `app_metadata.firstvue_admin`. Storage buckets are private with MIME allowlists. Those are real strengths.

The critical gap is that **privacy is enforced in RPCs and Flutter, not in RLS**. Anyone holding the publishable key (it is in the public GitHub repo, which is correct for a client key) can select `phone`, `birthday`, coordinates, and other profile columns for any row with a non-null `display_name`, including profiles marked private.

### Payment readiness

**Not ready for live charges.** Architecture in repo is the right shape (hosted Checkout, webhook signature, idempotency table, no Stripe secrets in Flutter). Live: `create-checkout-session` responds to OPTIONS; `stripe-webhook` OPTIONS returns **500** (secrets likely missing); `send-email` and `media-storage` are **not deployed** (404). Prices are taken from Stripe Price IDs (good) but `planPrices` in the function is unused documentation. No CSP `connect-src` for Stripe. No refund authorization path. Test vs live credential split is documented only.

### Messaging readiness

**Parallel systems.** `fv_msg_*` tables and RPCs **are present on the live API**. Flutter still keeps legacy `direct_messages` (plaintext `body`, 2000 chars) and falls back when encrypted schema/register fails. Device X25519 private keys are stored **unwrapped** in `SharedPreferences` despite comments claiming a local wrapping secret. Protocol is envelope-v1 (X25519 + HKDF-SHA256 + AES-256-GCM via `package:cryptography` / Web Crypto) — **not** OpenMLS; do not call this “E2EE complete” until the legacy path is gone, keys are wrapped, and under-13 / entity-inbox flows are verified with signed-in roles.

### Whether it is safe to continue development

**Yes, continue feature development on a separate track**, but **do not expand messaging, monetization, or payments** until Repair phase 1–2 (emergency RLS + database/RLS) land. Do not treat the current live project as a hardened social network.

### Finding counts

| Severity | Count |
| --- | ---: |
| Critical | 2 |
| High | 14 |
| Medium | 18 |
| Low | 10 |

---

## 1. Environment confirmation

| Item | Value |
| --- | --- |
| Repository path | `/workspace` |
| Git remote | `github.com/hkendale16-create/Firstvue` (public) |
| Branch at audit start | `main` @ `5a4bb7b` (clean) |
| Audit branch | `cursor/firstvue-system-security-audit-195e` |
| Connected Supabase project | `sdssshegqdwobjelxzkp` (`https://sdssshegqdwobjelxzkp.supabase.co`) |
| Access method | Flutter publishable key via PostgREST `limit=0` existence probes + Auth `/settings` + Edge Function OPTIONS. **Supabase MCP: `needsAuth` (not used).** OpenAPI dump requires a secret key (not used). |
| Environment type | **Production** (public project, email confirmation on, real schema with user-facing tables). Not a dedicated staging project. |
| Local migrations | `supabase/migrations/` (59 SQL files, 20260810–20260915) plus operator paste files `supabase/apply_pending_migrations.sql`, `APPLY_*.sql` |
| Generated Dart DB types | **None** (no `database.types.dart` / supabase_codegen) |
| Netlify config | `/workspace/netlify.toml` (build `scripts/build-web.sh`, publish `build/web`, some security headers, **no CSP**) |
| Flutter host URL | **Not verified.** `firstvue.app` → lander; `firstvue.netlify.app` → unrelated Vue “first-vue” |

**Not printed:** API secrets, service-role keys, tokens, DB passwords, user records, message bodies, payment records.

If privileged catalog access is required later (exact `pg_policies`, indexes, Storage policies, Auth hooks), authenticate Supabase MCP or run the metadata SQL in the dashboard as the project owner. Phase 1 did not guess another project.

---

## 2. Live vs application inventory (metadata only)

### Capture method (once)

- Parsed all `create table` / `create view` / `create or replace function` in `supabase/migrations/`.
- Parsed all `.from('…')` and `.rpc('…')` under `lib/`.
- Probed live PostgREST with `GET /rest/v1/{table}?select=…&limit=0` (empty arrays only).
- Probed Dart RPCs with `OPTIONS` only (no execution).

### Tables / views

Flutter references **97** relations. SQL migrations define **114** tables + **3** views (`business_discovery_view`, `community_news_feed_view`, `rental_public_listings`). **No Dart table is missing from SQL.**

SQL-only (not queried via `.from` in Flutter): `bookings`, `business_claims`, `business_leads`, `business_services`, `categories`, `community_tags`, `email_outbox`, `entity_customers`, `entity_handles` (handles go through RPCs), `entity_inventory_items`, `feed_interactions` (RPC `record_feed_interaction`), `fv_msg_event_settings`, `fv_msg_moderator_keys`, `fv_msg_rate_events`, `notification_subscriptions`, `post_impressions` (RPC), `rental_private_locations`, `stripe_webhook_events`.

### Live presence (anon publishable key)

**Present (200, empty body):** core social, businesses, hubs, groups, stories, albums, shoutouts, rentals, views, and **most `fv_msg_*` tables**.

**Present but composite PK (200 after selecting real columns):** `community_hub_roles`, `community_members`, `profile_follows`, `business_memberships`, `fv_msg_members`, `entity_handles`, `user_preferences`, and others listed in the probe log.

**Missing from PostgREST schema cache (`PGRST205`):**

| Object | Flutter use | Impact |
| --- | --- | --- |
| `community_organizer_applications` | `organizer_application_service.dart` | Organizer apply/approve path breaks |
| `feed_interactions` | written via `record_feed_interaction` | Feeds analytics / recommended ranking side effects fail if the RPC expects the table |

**Anon `community_hubs` and `community_hub_roles` `limit=0` did not return `42P17`.** `has_hub_role` OPTIONS is 200, so `20260910_community_rls_recursion_media_delete.sql` helpers appear applied. Authenticated recursion was **not** retested (no user session).

### RPCs

Every Dart `.rpc` name returned OPTIONS 200, including messaging (`fv_msg_*`), feeds, handles, hub management, `replace_role_media` / `replace_business_avatar`, `delete_owned_business`, `is_firstvue_admin`.

### Enums / nullability / FKs / indexes

Not dumped from live `pg_catalog`. Migration-defined checks that matter:

- `community_hub_roles.role`: `creator | lead_leader | leader | admin | moderator`; `status`: `active | pending | revoked`. PK `(hub_id, profile_id)` — **no `id` column** (Flutter must not `.select('id')`).
- `business_memberships.role` extended in `20260911` to `owner | manager | staff | content_editor | moderator | analytics_viewer`.
- Unique partial indexes: `business_media_one_avatar_idx`, `business_media_one_cover_idx`, professional and profile equivalents.
- `direct_messages.body` `char_length between 1 and 2000`, plaintext.

### Storage buckets (from SQL, not downloaded)

| Bucket | Public | Size cap | MIME allowlist |
| --- | --- | --- | --- |
| `business-media` | false | 50 MB | jpeg/png/webp (later updates may add video) |
| `rental-media` | false | 50 MB | images + mp4/quicktime |
| `professional-media` | false | 50 MB | jpeg/png/webp |
| `profile-media` | false | 50 MB | images + common video |
| `community-news-media` | false | 50 MB | images + common video |
| `event-media` | false | 10 MB | jpeg/png/webp |
| `fv-msg-media` | false | 50 MB | encrypted blobs; **no MIME allowlist** in insert |
| `stories` | created if missing in `20260912` | policies reference `stories` | Flutter uploads stories to **`profile-media` / `stories/` subfolder**, not `MediaBucket` stories |

### Realtime (SQL)

`community_news_posts`, `feed_comments`, `profile_follows`, `communities`. Flutter also subscribes to `activity_notifications`, `direct_messages`, `fv_msg_messages`, `fv_msg_calls`. **`activity_notifications`, `direct_messages`, `fv_msg_messages`, `fv_msg_calls` are not added to `supabase_realtime` in the migrations reviewed.** Subscriptions on unpublished tables silently do nothing or error — messages/calls may not live-update until publication is granted.

### Extensions (SQL)

`pgcrypto`, `citext`; story cleanup attempts `cron` (`pg_cron`) if present.

### Generated types

Absent. Column fallbacks in `community_news_service.dart`, `community_hub_service.dart`, `community_news_media_service.dart` are evidence of past drift.

---

## 3. Feature-area findings (grouped)

### Authentication

Email/password only (`/auth/v1/settings`: email on, other providers off, `disable_signup=false`, `mailer_autoconfirm=false` → **confirm-email is on**). App requires 8-character passwords locally; server policy not visible. Forgot-password sends reset with **no redirect URL** in `resetPasswordForEmail` (dashboard Site URL must be correct). No MFA, passkeys off, no CAPTCHA in public settings. Auth errors shown to the user (`error.message`) — account enumeration via distinct signup vs login messages.

### Users and profiles

`ensure_user_profile` RPC plus insert fallback. Privacy maps exist (`field_visibility`) but **RLS does not honor them** (see FV-C01). `is_private` / `profile_visibility` are not in the public SELECT policy. `fetch_public_profile` is the intended gate and is granted to `authenticated` only — anon attackers use `.from('profiles')` instead.

### Businesses and entities

Approval workflow + `is_firstvue_admin`. Entity details jsonb on businesses/professionals/rentals. Handles via RPCs (`set_entity_handle`, etc.) — live. `delete_owned_business` is SECURITY DEFINER, owner-only — correct privileged path.

### Entity ownership and team roles

`has_business_role` exists. **No INSERT/UPDATE/DELETE policies for owners on `business_memberships`** after Phase 1 security (SELECT for member/owner; ALL for admin only). Owners cannot assign managers from the client. Messaging permission (`owner|manager|moderator`) cannot be granted without admin/SQL. This blocks entity customer inbox.

### Home

`HomeDiscoverySection` waits on coming-soon existence, then loads one tab’s businesses (limit 16) + people-to-follow + featured event. `HomeCommunityFeedBlock` is used on Feeds main, not the Home switch tab (Home is discovery cards). Pull-to-refresh increments `_homeRefreshToken` and reloads city + avatar.

### Feeds

Six tabs: Main (composer + ranked feed + stories tray), Communities, Groups, Trending, New, Recommended. Main calls `fetch_ranked_main_feed` then `_mapPostRows` waterfall. Missing `feed_interactions` table weakens Recommended/Trending personalization if the RPC writes fail.

### Explore / VUE

Client-side filter after over-fetch (`limit * 3`). Full-resolution video in grid (`explore_grid_video.dart`).

### Stories

Table live. Upload path uses **profile-media** `stories/` prefix. `20260912` storage policies for bucket `stories` do not cover that path. Expired-story cleanup function exists; cron may not be installed.

### Groups / communities / approvals

Hubs live; `has_hub_role` live. Flutter still swallows `community_hub_roles` errors and returns empty “Your communities”. Creation/leader/link reviews are SECURITY DEFINER admin RPCs (good — not client-trusted). `community_organizer_applications` missing live.

### Events / Happening Now

Realtime on `community_news_posts` in `whats_now_screen.dart`. Event media bucket 10 MB images only — video event covers will fail storage MIME.

### Rentals

`rental_public_listings` view live. Private locations table live; owners-only policy in SQL. GPS on public `business_locations` / profile coordinates is a privacy issue.

### Followers / sparks / comments / reposts / saves

Tables live. Several SELECT policies are `using (true)` for authenticated users (follows, members, hashtags, mentions, event attendance) — graph enumeration.

### Search

`search_autocomplete_service` + `search_message_recipients` RPC. No obvious rate limit besides messaging `fv_msg_rate_events`.

### Notifications

`activity_notifications` live; Realtime subscribe may be unpublished. Badge fetch on every Home init.

### Messaging / entity inbox

See FV-H05–H07 and section 10. Legacy + `fv_msg_*` both live.

### Privacy / parental

`fv_msg_parental` / `fv_msg_approved_contacts` live. `fv_msg_is_under_13` uses `birthday`. Birthday is also on `profiles` and may be world-readable (FV-C01). UI for parent approval is settings-only per messaging docs.

### Media and Storage

Private buckets, signed URLs 7 days, `upsert: false` on upload. No EXIF strip. Thumbnails = full object. `replace_*` RPCs live (23505 mitigation). Stories/media-type validation is extension/MIME, not magic-byte.

---

## 4. RLS and authorization

Migrations enable RLS on application tables reviewed. **Do not disable RLS.**

### Role matrix (from SQL, not live `pg_policies`)

| Actor | Typical grant |
| --- | --- |
| Signed-out | Public approved businesses, public hubs/groups, public news, stories unexpired, profile rows with `display_name` (too broad) |
| Normal user | Own profile write; social graph; create posts/comments/follows |
| Profile owner | Own media; `replace_profile_*` |
| Entity owner | Own business row/media; **not** membership writes |
| Entity team | Read/write where `has_business_role` used (media managers); messaging if role in allow-list **and** membership row exists |
| Group/community leaders | Hub helpers `is_active_hub_manager`; editor RPCs |
| Event hosts | Event media/chat RPCs |
| Moderators | Hub role `moderator`; `fv_msg` staff helpers |
| Administrators | JWT `firstvue_admin` or `profiles.account_type=admin` via `is_firstvue_admin()` |
| Parent-supervised | `fv_msg_contact_allowed` / under-13 RPC — **unverified against live birthday data** |

### `community_hub_roles` — PostgreSQL `42P17`

**Exact recursion chain (historical, `20260829` + `20260907`):**

1. `community_hubs` SELECT USING includes `exists (select 1 from community_hub_roles r where r.hub_id = community_hubs.id …)`.
2. `community_hub_roles` FOR ALL USING includes `exists (select 1 from community_hubs h where h.id = community_hub_roles.hub_id …)` **and** `exists (select 1 from community_hub_roles r where r.hub_id = community_hub_roles.hub_id and r.profile_id = auth.uid() …)`.
3. Postgres evaluates **all** permissive policies. The self-select on `community_hub_roles` re-enters RLS on the same table → **`42P17` infinite recursion**.

**Queries affected:** any SELECT/INSERT/UPDATE/DELETE on `community_hubs` or `community_hub_roles` that makes the recursive policy relevant — including Flutter `fetchYourHubs`, `isActiveManager`, hub create, nearby hubs when the recursive SELECT policy is present.

**Does it prevent approved communities from loading?** Yes, when the recursive policies are live: hub list and “Your communities” fail or return empty. Flutter **catches hub_roles errors and continues with `roleRows = []`**, so the Communities tab can look empty even when public hub SELECT still works.

**Live Phase 1 evidence:** anon `limit=0` on both tables returned 200; `has_hub_role` exists. That matches `20260910` (SECURITY DEFINER boolean helpers, `search_path = public`, policies rewritten to call helpers instead of self-select). **Authenticated 42P17 was not retested.**

**Safe non-recursive repair (do not disable RLS):** keep/verify `has_hub_role` and `is_active_hub_manager` as SECURITY DEFINER, `stable`, boolean-only, locked `search_path`, tight GRANT. Hub and hub_roles policies must **never** `exists (select … from community_hub_roles)` under invoker RLS. Re-test as: anon, member, pending, manager, admin. Remove the Flutter swallow only after tests pass.

### Other RLS issues

- `using (true)` SELECT on follows, members, hashtags, mentions, hub follows, shoutout sparks, media albums (public), news sparks — social graph harvest.
- `business_memberships` missing owner writes.
- `is_firstvue_admin()` reads `profiles.account_type`; profiles policies do not call it (no cycle found).
- SECURITY DEFINER functions generally set `search_path = public` in later migrations — good. Dynamic SQL in `replace_role_media` uses `%I` and a table whitelist.
- No service-role key in Flutter or web assets (only Edge Functions via `Deno.env`).
- `review_*` community RPCs check `is_firstvue_admin()` server-side — correct. Do not move those checks into Flutter.

---

## 5. Authentication security (current / risk / recommendation)

| Control | Current | Risk | Recommendation (Phase 2+, do not enable now) |
| --- | --- | --- | --- |
| Email verification | `mailer_autoconfirm=false` (confirm required) | Users who skip mail never get a session (`signUp` session null handled) | Keep on; tighten templates and redirect URLs |
| Password strength | App min 8; server unknown | Weak passwords | Align Auth min length + HaveIBeenPwned / leaked-password protection |
| MFA | Passkeys off; no MFA in public settings | Admin/entity takeover | TOTP MFA required for `firstvue_admin` and entity owners before payments |
| Reauthentication | None for delete business | Destructive actions with stolen session | Reauth / step-up before `delete_owned_business` |
| Refresh rotation / session expiry | Not inspectable without dashboard | Stolen refresh | Enable reuse detection; shorter web sessions |
| Device/session management | None in app | No remote logout | Auth session list UI later |
| Password reset | `resetPasswordForEmail(email)` no `redirectTo` | Open redirect / wrong Site URL | Explicit allow-listed `redirectTo`; hash tokens |
| Login / OTP rate limits | Unknown (dashboard) | Stuffing | Enable Auth rate limits + WAF |
| CAPTCHA / Turnstile | Not in app or public settings | Bot signups | Turnstile on signup/reset before scale |
| Suspicious login | None | Credential stuffing | Auth hooks / alerting |
| Redirect URLs | Documented as Netlify placeholder | Auth tokens to wrong origin | Pin production Flutter URL only |
| Account enumeration | Distinct AuthException messages | Email oracle | Generic errors |

---

## 6. Secrets and privileged operations

### Secret scan (locations/types only — values not printed)

| Location | Type | Action |
| --- | --- | --- |
| `lib/config/supabase_config.dart`, `web/seo-bootstrap.js` | Supabase **publishable** key (client) | Expected in client; rotate if it was ever a legacy JWT anon key mixed with service role. Not a service-role key. |
| `supabase/functions/*/index.ts` | Reads `SUPABASE_SERVICE_ROLE_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `AWS_*` from **env** | Keep in Edge secrets only; rotate if those secrets were ever pasted into chat/SQL |
| `PHASE2_PAYMENTS.md`, `PHASE3_AWS.md` | Placeholder names | Fine |
| Flutter assets / `.env` files | None found | Keep `.env` out of git (already no `.env` committed) |
| Git history | No `sk_live` / `eyJhbGci` / `whsec_` matches in current tree | Optional `gitleaks` on full history in Phase 2 |

**No service-role key in Flutter or browser code.**

### Operations that must stay (or move) server-side

Already Edge/RPC (keep there): Checkout session, Stripe webhook, `delete_owned_business`, `review_*` community RPCs, `replace_*` media, `is_firstvue_admin`, `fv_msg_open_*`, rate limit RPC.

**Still too client-shaped (move to Edge/RPC in later phases):**

- Direct inserts into `community_hub_roles` from Flutter (role string client-supplied — constrain via `invite_hub_leader` / `review_hub_role` only).
- Organizer `community_organizers` upsert after local application insert.
- Admin UI that updates `businesses.status` if any path bypasses admin RPC (verify `business_submission_service` uses RLS admin policy only).
- Refunds, price changes, subscription cancels — no Flutter Stripe secret today; keep it that way.
- Moderation enforcement / report resolution.
- Privileged messaging: member role grants, moderator key install, migration delete of legacy plaintext.

---

## 7. Storage and upload

- Buckets private; folder `[auth.uid()]/…` for most uploads; messaging bucket first segment = conversation UUID + `fv_msg_can_access`.
- Signed URL TTL **7 days** — long-lived capability URLs; cache/CDN may keep 404s.
- Size limits 10–50 MB at bucket; Flutter also checks bytes for some flows.
- Type checks: MIME + extension; **no magic-byte**; SVG not in allowlists (good); `fv-msg-media` has **no MIME allowlist**.
- Video thumbnails: full video download (`SignedMediaThumbnail`, `explore_grid_video`, `feed_autoplay_video`).
- No EXIF/GPS strip on upload — photos may leak coordinates even if profile GPS is hidden.
- Orphan cleanup: `replace_*` deletes old DB rows; storage delete is best-effort in Flutter. `cleanup_expired_stories` exists; OPTIONS 200.
- Duplicate avatars: unique indexes remain; see FV-H08.
- Stories: uploaded to `profile-media`, while `20260912` policies discuss bucket `stories` — policy mismatch risk.
- Messaging attachments: encrypt-then-upload in new stack; legacy `direct_messages.media_path` unencrypted.

### `business_media_one_avatar_idx` — PostgreSQL `23505`

**Cause:** unique partial index `(business_id) WHERE media_role = 'avatar'` (same for cover; professional/profile analogs). Delete-then-insert races, or insert when a row already exists.

**Live:** `replace_business_avatar` / `replace_role_media` OPTIONS 200. Flutter tries RPC first, then `RoleMediaReplace.upsertInPlace` (UPDATE by id, INSERT only if missing, UPDATE on 23505).

**Safe correction (do not drop the index):**

1. **Keep the unique index.**
2. Prefer **UPDATE in place** (current RPC `20260910` path) or `ON CONFLICT` on a real unique constraint if you add `(business_id, media_role)` uniqueness for those roles.
3. **Transactional replacement** inside `replace_role_media` (already single function).
4. **Conflict handling** in Flutter as backup only.
5. **Historical duplicate cleanup:** `DELETE FROM business_media a USING business_media b WHERE a.business_id = b.business_id AND a.media_role = 'avatar' AND a.ctid < b.ctid` (operator-run, backup first) — Phase 2, not now.

Same pattern for cover + professional + profile indexes.

---

## 8. Application and browser security (ASVS-oriented)

| Topic | State |
| --- | --- |
| XSS / HTML / SVG | No `Html`/`flutter_html`; text via `Text`/`SocialRichText`. SVG uploads not in MIME allowlists. |
| SQL / command injection | PostgREST parameterized; `replace_role_media` uses `%I` + whitelist. |
| Open redirects / deep links | `launchUrl` on any `http(s)` in posts and professional sites; billing `?billing=` only shows a snackbar (low). Deep links `?business|profile|post=` open in-app. |
| Input validation | Password min 8, some length checks on DMs; much UGC unbounded relative to DB checks. |
| Client-trusted authz | Admin nav hidden in UI; real checks are RLS/RPC. Hub role insert still client-shaped. |
| Local storage | Theme prefs; **messaging private key in SharedPreferences**. |
| Logs | `debugPrint` / `print` of Postgrest codes/messages (no bodies seen); avoid logging RPC payloads. |
| CSRF | Bearer tokens, not cookies for API — typical Supabase. |
| CORS | Edge functions `Access-Control-Allow-Origin: *`. Supabase API also `*`. |
| Clickjacking | `netlify.toml` has `X-Frame-Options: DENY`. |
| Security headers in repo | HSTS, nosniff, Referrer-Policy, Permissions-Policy (camera/mic empty, geo self). **No Content-Security-Policy.** |
| Live Flutter headers | Flutter site URL not confirmed; unrelated Netlify Vue app lacks these headers. |
| Dependencies | CI runs analyze/test/build; **no Dependabot/secret scanning** visible on the public repo API (`null`). |
| Service worker | Default Flutter web SW possible on deploy; not customized; stale cache risk after deploys (`cache-control: must-revalidate` in toml not set for hashed assets beyond Netlify defaults). |

**Netlify readiness (config only, headers not changed):** HSTS/preload present; no CSP (needed before Stripe.js/Elements); no explicit WAF; SPA redirect `/* → /index.html` 200 (correct for Flutter); preview protection not configured in-repo.

---

## 9. Abuse and social-platform security

| Surface | Protection today | Gap |
| --- | --- | --- |
| Account creation | Email confirm | No CAPTCHA, signup enabled |
| Login | Auth vendor limits unknown | No app lockout |
| Message requests | `fv_msg_within_rate_limit` + `fv_msg_rate_events` | Legacy DMs have **no** rate table |
| Follow / spark / comment / repost | Unique indexes + 23505 swallow | Easy to script with user JWT |
| Search | None | Enumeration |
| Uploads | Size + MIME | No virus scan; no per-user quota |
| Events / communities | Admin review RPCs for hubs | Direct group create still possible under older policies |
| Reports | `fv_msg_reports` insert own | No moderator workflow UI; bundles not always wrapped to moderator keys |
| Entity inquiries | `rental_inquiries` / leads | No velocity limit |
| Blocks | `fv_msg_blocks` account-level in new schema | Legacy DMs **not** wired to blocks; “block one account → all identities” is **not** implemented end-to-end |

Recommend (later): Auth + Edge rate limits, device-risk, progressive delays, Turnstile on burst, spam scoring on links, temp restrictions, block fan-out by `auth.users` id + linked businesses, report queue with audit log (`fv_msg_audit` exists).

---

## 10. Messaging security readiness

**Do not claim production E2EE.** Verified:

- New stack encrypts with envelope-v1 (`lib/messaging/crypto/messaging_crypto.dart`) using reviewed primitives (`package:cryptography`), not a home-grown cipher.
- Live `fv_msg_*` tables/RPCs exist.
- Legacy `direct_messages.body` is plaintext; UI/service still present; fallback when `schemaReady` is false.
- Device private key stored as raw base64 in SharedPreferences (web origin storage, not hardware-backed, **not actually wrapped**).
- Group/entity epoch rotation and `fv_msg_key_envelopes` are designed; not penetration-tested here.
- `fv-msg-media` private; encryption depends on client correctness.
- Local search is an opt-in flag, not an encrypted index.
- Under-13: RPC uses `birthday`; birthday may be exposed (FV-C01) and parental UI is incomplete.
- Calls: WebRTC signaling rows; SDP in DB; 1:1 only.
- Long-term group protocol: docs correctly defer OpenMLS; do not invent custom group crypto.

**Before relying on messaging:** apply remaining Storage/Realtime publication, wrap device keys, stop writing plaintext, verify blocks across identities, lock under-13, rotate keys on member removal, and keep using a reviewed library (current `cryptography` / future OpenMLS) — no custom crypto.

---

## 11. Child-account and privacy

| Control | Architecture |
| --- | --- |
| Verified parental relationship | `fv_msg_parental` table; not tied to a verified ID vendor |
| Parent-approved contacts | `fv_msg_approved_contacts` + `fv_msg_contact_allowed` |
| Location / call / download / media permissions | Profile GPS columns; WebRTC calls; no COPPA-grade permission matrix in UI |
| Supervision levels | Not a real graduated model |
| Data minimization | Broad profile SELECT; news posts retain body |
| Account deletion / export / retention | No GDPR-style export; business delete anonymizes reviews; no user-wide erasure RPC |

**Questions for qualified counsel (not legal conclusions):** whether birthday+parental tables constitute a child-directed service; whether public profile PII + GPS photo metadata requires a DPIA; retention of plaintext DMs; California/EU marketing + tracking; what “parental consent” must look like before under-13 messaging is enabled.

---

## 12. Payment-security readiness (no implementation in Phase 1)

Required future architecture vs today:

| Requirement | Today |
| --- | --- |
| Stripe Checkout or Elements | Checkout session Edge Function exists |
| No raw cards in Supabase | Yes (if Checkout only) |
| Server-created sessions | Yes |
| Server-calculated prices | Price IDs from env (good); Flutter sends `plan` name only |
| Webhook signatures | Code present; live OPTIONS **500** |
| Idempotency | `stripe_webhook_events` table live (composite probe: table exists) |
| Separate test/live secrets | Documented, not verified |
| Audit logs | Email outbox / subscription triggers; not a payment audit log |
| Refund authorization | Missing |
| No secrets in Flutter | Confirmed |
| TLS + CSP | HSTS in toml; **no CSP** `frame-src`/`connect-src` for Stripe |

**Work required before real charges:** deploy webhook with live secrets, confirm checkout in test mode, add CSP, admin MFA, refund RPC, never log Stripe payloads to clients, pin `FIRSTVUE_WEB_URL`, disable Checkout until PII RLS is fixed.

---

## 13. Performance and bottlenecks

### Runtime Home / Feeds measurement

| Item | Result |
| --- | --- |
| Two cold + two warm Home | **Not measured** — no confirmed Flutter production URL; Flutter SDK not installed (one-build budget unused) |
| Two cold + two warm Feeds | **Not measured** (same) |
| Bundle size | **Not measured** (no release build) |
| Application-shell / useful-content / interactive | Static estimate only (below) |

### Static Home (index 0) request graph

1. `Supabase.initialize` (auth restore from local storage — blocking before `runApp`).
2. Theme from prefs (non-blocking vs network).
3. Notification badge `unreadCount`.
4. City chip: `UserPreferencesService.fetch`.
5. Avatar: profile media signed URL.
6. **Blocking:** `hasComingSoonBusinesses` (`businesses` filter `coming_soon`, limit 1) before any Home tab UI.
7. Selected tab: trending/new/recommended businesses (`select` with embedded `business_locations`, limit 32) + per-card saved-state queries + people-to-follow on Recommended.
8. No Home newsfeed on tab 0 (discovery cards only).

**Duplicate clients:** single `Supabase.initialize` — good.  
**Location:** Home city is prefs, not GPS on startup — good. Geolocator used in trending “near you” paths.

### Static Feeds (index 1) request graph

1. New `FeedsScreen` (not kept alive when leaving Home — `switch` destroys state; every tab visit is a **cold** widget init).
2. Main tab: stories tray + `fetch_ranked_main_feed` + **~12 sequential** `_mapPostRows` queries + repost ids/counts + signed URLs per media item + Realtime subscribe.
3. `fetch_ranked_main_feed` (SECURITY DEFINER): scans eligible posts with **lateral `count(*)` on sparks and comments**, impression join, follow/group affinity — **recommend indexes only as tied to this query:** `(community_news_post_sparks.post_id)`, `(feed_comments.media_id)` already exist in places; **missing supporting indexes** should be confirmed with `EXPLAIN` in Phase 2 (not applied now). `feed_post_is_eligible` + hub_roles joins inside other feed RPCs are CPU-heavy under RLS.
4. Column fallback retries can **triple** failed post selects on schema mismatch.
5. Adjacent PageView tabs may mount and fire extra feed RPCs.

### Other performance notes

- Explore over-fetch ×3 then filter client-side.
- `select` lists are explicit (no widespread `select('*')` in Dart) — good.
- No large `count=exact` in the probe (we used `Prefer: count=none`).
- Broken media: 7-day signed URLs + video controllers without poster → repeat downloads.
- Realtime: Home/Feeds/WhatsNow/comments unsubscribe in `dispose` — good; unpublished tables waste channels.

**Index recommendations (query-tied, not applied):**

1. Confirm `community_news_posts (status, created_at desc)` / visibility — used by ranked/new feeds.
2. Confirm sparks `(post_id)` for the lateral count in `fetch_ranked_main_feed`.
3. `businesses (status, coming_soon, created_at)` for Home blocker query.
4. Do **not** add speculative indexes on unused SQL-only tables.

---

## 14. Operational security

| Area | State |
| --- | --- |
| DB backups / restore tests | Not visible from client access — confirm PITR in dashboard |
| Log retention / alerts | Not configured in-repo |
| Admin audit | `fv_msg_audit` for messaging staff; no general admin audit table for approvals |
| Credential rotation | Publishable key in git; rotate dashboard secrets after any paste |
| Dependency scanning | GitHub `security_and_analysis` fields `null`; CI has no `osv`/`audit` |
| Branch protection | API 403 (cannot read); **public repo** |
| MFA on Supabase/GitHub/Netlify/Stripe | Unknown; required before payments |
| Incident / breach / account-compromise procedures | Not in repo |
| Emergency feature-disable | `FeatureFlags.liveStreamingEnabled` only; no remote kill-switch |

---

## Findings table

Severity: **Critical** = data exposure, loss, auth bypass, secret exposure, payment compromise, or widespread outage. **High** = major feature failure or exploitable authorization. **Medium** = meaningful weakness. **Low** = hardening.

### Critical

#### FV-C01 — Profile PII readable despite privacy settings

| Field | Value |
| --- | --- |
| Severity | Critical |
| Area | Users and profiles / Privacy / RLS |
| Code files | `lib/services/user_profile_service.dart`, `profile_privacy_service.dart`, `follow_service.dart`, `web/seo-bootstrap.js` |
| Database objects | `public.profiles`; policies `Public can read owner display identities`, `Authenticated read member profile summaries` |
| Expected | `field_visibility` / `is_private` enforced for phone, birthday, GPS, address; anon sees only public cards |
| Actual | Permissive SELECT `using (display_name is not null)` is **row-level**. Postgres RLS does not hide columns. `fetch_public_profile` filters fields but is optional. Private profiles with a display name remain selectable. |
| Evidence | `20260811_ai_commerce_owner_connections.sql` (anon+auth); `20260823_social_followers_and_post_visibility.sql`; columns added in `20260821` (lat/long) and `20260903` (phone, birthday). No column grants. **No production PII values were read for this report.** |
| Impact | Any holder of the public publishable key can harvest phones, birthdays, coordinates, account_type. Child-age inference. Undermines parental and privacy UI. |
| Recommended correction | Replace broad profile SELECT with: own row; `fetch_public_profile` SECURITY DEFINER returning stripped jsonb; **or** a `profile_public_cards` view with only safe columns and `is_private = false`. Drop `using (display_name is not null)` for `select *`. Keep RLS enabled. |
| Fix location | New migration + Flutter to use RPC/view only |
| Effort | M |
| Migration required | Yes |
| Production risk | Medium (breaking clients that select extra columns — Flutter already often selects named columns) |
| Verification | Anon `select phone, birthday, latitude from profiles limit 1` must fail or return null columns; owner can still read self; private profile hidden from stranger |

#### FV-C02 — Privacy RPC granted to authenticated only while table remains world-readable

| Field | Value |
| --- | --- |
| Severity | Critical (same exposure class as FV-C01; listed separately because fixing the RPC without fixing RLS fails) |
| Area | Privacy |
| Code files | `lib/services/profile_privacy_service.dart` |
| Database objects | `fetch_public_profile`, `profile_field_is_visible` |
| Expected | Only gate for profile reads |
| Actual | GRANT to `authenticated`; anon uses REST table. Comment says “Enforced by fetch_public_profile” — not enforced for REST. |
| Evidence | `20260903_phase1_media_communities_privacy.sql` grant + comment |
| Impact | Same as FV-C01 |
| Recommended correction | Same migration as FV-C01; revoke direct SELECT of sensitive columns |
| Fix location | SQL |
| Effort | S (if combined with FV-C01) |
| Migration required | Yes |
| Production risk | Medium |
| Verification | Anon cannot select sensitive columns; authenticated stranger cannot either |

### High

#### FV-H01 — `42P17` hub RLS recursion (historical; authenticated path unverified)

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Communities and approvals |
| Code files | `lib/services/community_hub_service.dart` |
| Database objects | `community_hubs`, `community_hub_roles`, `has_hub_role`, `is_active_hub_manager` |
| Expected | Approved public hubs and membership always load |
| Actual | Original policies recurse (see §4). Flutter swallows hub_roles errors → empty “Your communities”. Live anon SELECT succeeded; helpers exist. |
| Evidence | `20260829` FOR ALL self-select; `20260907` hub SELECT `exists(hub_roles)`; `20260910` rewrite; live OPTIONS `has_hub_role` 200; `fetchYourHubs` try/catch |
| Impact | Communities feature outage for signed-in managers if recursion remains on authenticated policies |
| Recommended correction | Verify `pg_policies` in dashboard; do not query `community_hub_roles` from invoker policies; test all roles; then remove Flutter swallow |
| Fix location | SQL verify + Flutter |
| Effort | S–M |
| Migration required | Only if live policies ≠ `20260910` |
| Production risk | Low if already applied; High if a later paste reintroduced `20260829` |
| Verification | Signed-in manager SELECT hubs and hub_roles; `explain` without 42P17 |

#### FV-H02 — Owners cannot write `business_memberships`

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Entity ownership / Messaging |
| Code files | `lib/messaging/services/fv_messaging_service.dart` |
| Database objects | `business_memberships` policies in `20260811_phase1_security_hardening.sql` |
| Expected | Owners/managers assign team roles |
| Actual | SELECT for self/owner; ALL only for admin. No owner INSERT. |
| Evidence | Policy list; Flutter reads memberships for messaging permission |
| Impact | Entity customer inbox and team messaging cannot be staffed without SQL/admin |
| Recommended correction | SECURITY DEFINER `grant_business_role` / `revoke_business_role` with owner check; never allow client to set `role=owner` |
| Fix location | New migration + small Flutter |
| Effort | M |
| Migration required | Yes |
| Production risk | Low |
| Verification | Owner inserts manager; manager cannot promote self to owner; staff cannot |

#### FV-H03 — `community_organizer_applications` missing live

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Communities / Events |
| Code files | `lib/services/organizer_application_service.dart` |
| Database objects | `community_organizer_applications` |
| Expected | Table in schema cache |
| Actual | `PGRST205` |
| Evidence | Live probe |
| Impact | Organizer apply/approve broken |
| Recommended correction | Apply `20260813_organizer_applications.sql` or recreate; reload PostgREST schema |
| Fix location | SQL |
| Effort | S |
| Migration required | Yes if never applied |
| Production risk | Low |
| Verification | `limit=0` 200; signed-in insert own row |

#### FV-H04 — `feed_interactions` missing live

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Feeds / Performance |
| Code files | `lib/services/feed_interaction_service.dart` |
| Database objects | `feed_interactions`, `record_feed_interaction` |
| Expected | Table exists (RPC OPTIONS 200) |
| Actual | Table `PGRST205`; RPC may error at runtime |
| Evidence | Live probe vs `20260906` |
| Impact | Recommended/trending personalization and analytics fail; extra errors on every interaction |
| Recommended correction | Apply table+RLS+GRANTS from `20260906`; notify PostgREST |
| Fix location | SQL |
| Effort | S |
| Migration required | Yes |
| Production risk | Low |
| Verification | RPC insert as user; stranger cannot SELECT others’ rows |

#### FV-H05 — Legacy plaintext DMs still live

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Messaging |
| Code files | `lib/services/messaging_service.dart`, `lib/screens/conversation_screen.dart` |
| Database objects | `direct_messages.body` |
| Expected | Ciphertext only for new product |
| Actual | Plaintext column; fallback path; operators with service role can read all DMs |
| Evidence | `20260811_messaging_and_comments.sql`; live table 200 |
| Impact | Messaging confidentiality not met; migration must not delete until counts verified |
| Recommended correction | Stop inserts to plaintext; finish `fv_msg_migration`; restrict legacy SELECT; never custom crypto |
| Fix location | Flutter + SQL |
| Effort | L |
| Migration required | Yes (policies, not drop yet) |
| Production risk | Medium |
| Verification | New send writes `fv_msg_messages` only; legacy read-only |

#### FV-H06 — Device private keys stored unwrapped

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Messaging |
| Code files | `lib/messaging/crypto/device_keystore.dart` |
| Database objects | `fv_msg_devices` (public keys only — OK) |
| Expected | Wrapped private key; comment claims wrapping secret |
| Actual | `setString(_privKey, base64Encode(pair.privateKey))` |
| Evidence | File contents vs comment |
| Impact | XSS, shared computer, or backup of origin storage yields every conversation secret unwrap |
| Recommended correction | Wrap with Web Crypto + user passphrase (already sketched in recovery); never store raw private key |
| Fix location | Flutter |
| Effort | M |
| Migration required | No |
| Production risk | Medium (existing devices need re-wrap) |
| Verification | Storage inspection shows wrapped blob only |

#### FV-H07 — Messaging Realtime tables not in publication

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Messaging |
| Code files | `direct_conversation_page.dart`, `conversation_screen.dart`, `fv_call_service.dart` |
| Database objects | `supabase_realtime` publication |
| Expected | `fv_msg_messages`, `direct_messages`, `fv_msg_calls`, `activity_notifications` published |
| Actual | Migrations add news posts, comments, follows, communities only |
| Evidence | `alter publication` grep |
| Impact | Inbox/call UI requires manual refresh; looks “broken” |
| Recommended correction | `alter publication supabase_realtime add table` those tables; replica identity default |
| Fix location | SQL |
| Effort | S |
| Migration required | Yes |
| Production risk | Low |
| Verification | Insert message → subscriber fires |

#### FV-H08 — Avatar unique index `23505` still a race without RPC

| Field | Value |
| --- | --- |
| Severity | High (feature-breaking on avatar/cover) |
| Area | Media |
| Code files | `role_media_replace.dart`, `business_media_service.dart`, `profile_media_service.dart`, `professional_media_service.dart` |
| Database objects | `business_media_one_avatar_idx` (and cover/professional/profile analogs) |
| Expected | One avatar per owner |
| Actual | Index correct; old delete-then-insert races. Live RPC exists; Flutter fallback UPDATE-in-place. Duplicates may already exist if index created `if not exists` after dupes. |
| Evidence | `20260825`; `20260910` comment; tests in `role_media_replace_test.dart` |
| Impact | Entity profile photo save fails with 23505 |
| Recommended correction | See §7 — UPDATE/upsert/transaction; cleanup dupes; **do not drop index** |
| Fix location | SQL cleanup + keep RPC |
| Effort | S–M |
| Migration required | Cleanup only |
| Production risk | Medium (cleanup) |
| Verification | Replace avatar twice quickly; one row; no 23505 |

#### FV-H09 — Home/Feeds load waterfall and expensive ranked RPC

| Field | Value |
| --- | --- |
| Severity | High (widespread slowness, not a security hole) |
| Area | Home / Feeds / Performance |
| Code files | `home_discovery_section.dart`, `home_community_feed_block.dart`, `community_news_service.dart`, `20260905`/`20260906` feed functions |
| Database objects | `fetch_ranked_main_feed`, sparks, comments, impressions |
| Expected | One round-trip, useful content fast |
| Actual | Coming-soon probe blocks Home chrome; ranked RPC laterals `count(*)`; 12 sequential hydrations; signed URL per media; full video for thumbs |
| Evidence | Code paths cited; no live Flutter timings |
| Impact | Slow refresh/page load — matches the reported symptom |
| Recommended correction | Parallelize `_mapPostRows`; SQL view/RPC returning hydrated cards; poster images; don’t block UI on coming-soon; `EXPLAIN` then indexes in §13 |
| Fix location | Flutter + optional SQL |
| Effort | M–L |
| Migration required | Optional |
| Production risk | Low |
| Verification | Two cold/two warm Home & Feeds after Flutter URL exists; request count down |

#### FV-H10 — 7-day signed URLs and full-file video thumbs

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Media / Performance / Storage |
| Code files | `media_storage_service.dart`, `signed_media_viewer.dart`, `explore_grid_video.dart` |
| Database objects | Storage objects |
| Expected | Short-lived URLs; thumbnails |
| Actual | TTL 604800; video controller on thumbs |
| Evidence | `createSignedUrl(path, 604800)` |
| Impact | Bandwidth, battery, leaked URL window, retry storms on 404 |
| Recommended correction | 1-hour URLs; image posters; transform API if enabled |
| Fix location | Flutter |
| Effort | M |
| Migration required | No |
| Production risk | Low |
| Verification | Network panel: no full MP4 for off-screen thumbs |

#### FV-H11 — Stripe webhook unhealthy; email/media functions missing

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Payments / Ops |
| Code files | `supabase/functions/stripe-webhook`, `create-checkout-session`, `send-email`, `media-storage` |
| Database objects | `stripe_webhook_events` |
| Expected | Checkout + signed webhook + optional SES |
| Actual | Checkout OPTIONS 200; webhook OPTIONS **500**; send-email/media-storage **404** |
| Evidence | Live OPTIONS |
| Impact | Paid plans will not sync; AWS media flag would fail |
| Recommended correction | Configure secrets; redeploy webhook; keep `verify_jwt=false` **only** on webhook with signature check |
| Fix location | Supabase dashboard + deploy |
| Effort | S |
| Migration required | No |
| Production risk | Low (test mode first) |
| Verification | Stripe CLI signed event → row in `stripe_webhook_events` |

#### FV-H12 — No CSP; Edge CORS `*`

| Field | Value |
| --- | --- |
| Severity | High (before payments / messaging) |
| Area | Browser / Netlify |
| Code files | `netlify.toml`, Edge `corsHeaders` |
| Database objects | — |
| Expected | CSP, tight function CORS |
| Actual | No CSP; `Access-Control-Allow-Origin: *` on functions |
| Evidence | Files + firstvue.netlify.app is not this app |
| Impact | XSS becomes data theft; Stripe/Elements need CSP allowlists |
| Recommended correction | CSP in Netlify; function CORS to `FIRSTVUE_WEB_URL` |
| Fix location | `netlify.toml`, functions |
| Effort | M |
| Migration required | No |
| Production risk | Medium (mis-set CSP breaks app) |
| Verification | Header present; app + Checkout still load |

#### FV-H13 — `using (true)` social graph SELECT

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Followers / Groups / RLS |
| Code files | follow/community services |
| Database objects | `profile_follows`, `community_members`, `community_follows`, `event_attendance`, `hashtags`, `post_mentions`, … |
| Expected | Least privilege |
| Actual | Authenticated can read entire tables |
| Evidence | `using (true)` grep in migrations |
| Impact | Scrape all follows, members, mentions |
| Recommended correction | Restrict to public entities / participants; keep lists via RPCs like `list_profile_followers` |
| Fix location | SQL |
| Effort | M |
| Migration required | Yes |
| Production risk | Medium (breaking naive selects) |
| Verification | Stranger cannot dump all `profile_follows` |

#### FV-H14 — Client-supplied hub role insert

| Field | Value |
| --- | --- |
| Severity | High |
| Area | Communities / Authz |
| Code files | `community_hub_service.dart` |
| Database objects | `community_hub_roles` INSERT |
| Expected | Only `invite_hub_leader` / `review_hub_role` |
| Actual | Flutter inserts `{hub_id, profile_id, role, status}` |
| Evidence | `.from('community_hub_roles').insert` |
| Impact | If INSERT policy is loose, privilege escalation; if tight, feature errors |
| Recommended correction | Remove client insert; use RPCs only |
| Fix location | Flutter + SQL |
| Effort | M |
| Migration required | Tighten WITH CHECK |
| Production risk | Medium |
| Verification | Cannot insert `role=admin` for another hub |

### Medium

| ID | Area | Summary | Effort | Migration |
| --- | --- | --- | --- | --- |
| FV-M01 | Auth | No MFA, CAPTCHA, or leaked-password protection | M | No (dashboard) |
| FV-M02 | Auth | Password reset without explicit `redirectTo`; AuthException messages enumerate accounts | S | No |
| FV-M03 | Auth | `resetPasswordForEmail` / signup lack Turnstile | M | No |
| FV-M04 | Profiles | `account_type` still readable; JWT admin is preferred | S | Yes |
| FV-M05 | Storage | No EXIF strip; GPS in images | M | No |
| FV-M06 | Storage | Stories path vs `stories` bucket policies | S | Yes |
| FV-M07 | Storage | `fv-msg-media` no MIME allowlist | S | Yes |
| FV-M08 | Storage | Event-media 10 MB images only vs video UI | S | Yes |
| FV-M09 | App | `launchUrl` any https (phishing from UGC) | S | No |
| FV-M10 | App | `send-email` `verify_jwt=false` (not deployed; custom secret) | S | No |
| FV-M11 | App | Public GitHub + publishable key (expected) but no secret scanning/Dependabot | S | No |
| FV-M12 | Abuse | No rate limits on follow/comment/spark/search | M | Yes/Edge |
| FV-M13 | Abuse | Legacy DMs ignore `fv_msg_blocks` | M | Yes |
| FV-M14 | Child | Birthday used for under-13 while possibly public (ties to FV-C01) | S | with C01 |
| FV-M15 | Ops | Public repo; branch protection unread; no incident runbooks | M | No |
| FV-M16 | Perf | Feeds `switch` destroys state (always cold); PageView warms neighbors | S | No |
| FV-M17 | Perf | Column-fallback retries multiply 400s | S | No |
| FV-M18 | Realtime | Duplicate channels if both Home news widgets and Feeds mount in future | S | No |

### Low

| ID | Area | Summary |
| --- | --- | --- |
| FV-L01 | Types | No generated Dart types — regenerate after schema freeze |
| FV-L02 | SQL | Duplicate `APPLY_*.sql` paste files vs versioned migrations — operators can apply stale policy sets |
| FV-L03 | SQL | SQL-only tables (`bookings`, `business_leads`, …) unused in Flutter — fine, keep RLS |
| FV-L04 | Headers | Permissions-Policy disables camera/mic globally — will break WebRTC until updated |
| FV-L05 | PWA | `web/manifest.json` still default Flutter branding |
| FV-L06 | CI | Web build in CI but no size budget / Lighthouse |
| FV-L07 | Admin | `is_firstvue_admin` still accepts `app_metadata.role=admin` string |
| FV-L08 | Docs | `PHASE1_SECURITY.md` still says to paste `apply_pending_migrations.sql` — dangerous vs 20260910 |
| FV-L09 | Messaging | OpenMLS deferred (correct); document `protocol` column |
| FV-L10 | Payments | `planPrices` map unused in checkout function |

---

## Repair plan (Phase 2+ — do not execute now)

Each phase: stop for review; never disable RLS; never expose secrets; preserve data; backup before risky SQL; test each role; measure Home/Feeds before/after when a Flutter URL exists.

### 1. Emergency security fixes

- **Scope:** FV-C01, FV-C02 (profile SELECT), confirm hub policies = `20260910`, revoke dangerous grants.
- **Files/migrations:** new `20YYMMDD_profiles_public_card_rls.sql`; optional Flutter switch to `fetch_public_profile` / view.
- **Risk:** Feed author names empty if SELECT too tight — provide a safe card view.
- **Tests:** anon/auth/owner/follower/private/admin matrix on `profiles`.
- **Rollback:** restore prior policies from backup; keep RLS on.

### 2. Database and RLS corrections

- **Scope:** FV-H01 verify, FV-H02 membership RPCs, FV-H03/H04 missing tables, FV-H07 publication, FV-H13 graph SELECT, FV-H14 hub inserts, FV-H08 dupe cleanup.
- **Files:** versioned migrations only (do not paste `apply_pending_migrations.sql` wholesale).
- **Risk:** Over-tight follows break follower lists — use existing list RPCs.
- **Tests:** SQL role tests + existing `community_hub_roles_rls_contract_test.dart` expanded to parse migration SQL.
- **Rollback:** `drop policy` / recreate previous named policies.

### 3. Authentication and abuse protection

- **Scope:** FV-M01–M03, M12, dashboard rate limits, Turnstile, reset `redirectTo`, generic errors.
- **Files:** `auth_screen.dart`, Auth dashboard (manual).
- **Risk:** Lock out real users if CAPTCHA misconfigured.
- **Tests:** signup/signin/reset happy path.
- **Rollback:** dashboard toggles.

### 4. Storage and upload security

- **Scope:** FV-H10 TTL, FV-M05–M08, stories bucket alignment, MIME for `fv-msg-media`.
- **Files:** `media_storage_service.dart`, storage SQL, thumbnail pipeline.
- **Risk:** Short TTL breaks cached images — resign on read (already the pattern).
- **Tests:** upload image/video/reject svg/exe; story after expiry 404.
- **Rollback:** revert TTL constant.

### 5. Performance corrections

- **Scope:** FV-H09, FV-M16–M17, indexes from `EXPLAIN` on `fetch_ranked_main_feed`.
- **Files:** `community_news_service.dart`, `home_discovery_section.dart`, feed SQL.
- **Risk:** Ranking change alters feed order.
- **Tests:** two cold/two warm Home & Feeds; request count; no N+1.
- **Rollback:** revert RPC to previous `create or replace`.

### 6. Messaging security

- **Scope:** FV-H05–H07, FV-H06 keystore, blocks fan-out, under-13 after FV-C01, OpenMLS later.
- **Files:** `lib/messaging/**`, `20260915` follow-up migration.
- **Risk:** Losing device keys locks users out — recovery passphrase first.
- **Tests:** `test/fv_messaging_test.dart`; role matrix; no plaintext new inserts.
- **Rollback:** keep legacy read-only.

### 7. Payment readiness

- **Scope:** FV-H11, FV-H12 CSP, refund RPC, MFA for operators, test-mode end-to-end.
- **Files:** functions, `netlify.toml`, `PHASE2_PAYMENTS.md`.
- **Risk:** Wrong webhook secret; double fulfill — idempotency table already there.
- **Tests:** Stripe test card; duplicate webhook; no `sk_` in client bundle.
- **Rollback:** disable Checkout feature flag.

### 8. Operational monitoring

- **Scope:** FV-M15, backups, Dependabot, branch protection, incident docs, remote kill-switch.
- **Files:** `docs/`, GitHub settings (manual).
- **Risk:** Low.
- **Tests:** restore drill on a copy, not production.
- **Rollback:** n/a.

---

## 16. Phase 1 completion

### Areas inspected

Environment, live table/RPC presence, migrations vs Flutter `.from`/`.rpc`/storage/realtime, RLS (SQL + limited live), Auth public settings, secrets scan (current tree), Storage SQL + upload code, ASVS/Netlify headers, abuse, messaging crypto/legacy, child/privacy architecture, payments functions (live OPTIONS), Home/Feeds static performance, ops/GitHub visibility.

### Critical findings

- **FV-C01 / FV-C02:** Profile privacy is not enforced by RLS; PII columns are selectable for named profiles.

### High findings

FV-H01 hub recursion residual/unverified auth path; FV-H02 membership writes; FV-H03/H04 missing live tables; FV-H05 plaintext DMs; FV-H06 unwrapped device keys; FV-H07 Realtime publication; FV-H08 avatar 23505; FV-H09 load waterfall; FV-H10 signed URL/video thumbs; FV-H11 Stripe/functions; FV-H12 CSP/CORS; FV-H13 graph `using (true)`; FV-H14 client hub-role insert.

### Confirmed bottlenecks

Home blocked on coming-soon probe; ranked feed laterals + ~12 hydration queries; 7-day signed URLs; full video for thumbnails; Feeds widget always remounts. **Not** confirmed with two cold/two warm traces (no Flutter host / no release build).

### Supabase / code alignment

Mostly aligned; **exceptions:** `feed_interactions`, `community_organizer_applications`; no generated types; OpenAPI/pg_policies not dumped.

### Security readiness

**Not launch-ready** for a user-intensive social network until Repair phase 1.

### Messaging readiness

**Schema present, product not trustworthy yet** (plaintext fallback + unwrapped keys + unpublished Realtime).

### Payment readiness

**Not ready** for live charges (webhook 500, no CSP, no operator MFA).

### Report path

`docs/firstvue_system_security_audit.md`

### Recommended first correction phase

**Repair plan §1 — Emergency security fixes** (profile RLS/PII), then immediately **§2** (hub verify, missing tables, membership RPCs). Do not start messaging or Stripe work before that.

---

**Phase 1 complete. Stopped. Awaiting: `Approved — begin Phase 2.`**
