# FirstVue Monetization + VUE Bounties — Architecture Audit (Phase 1)

**Date:** 2026-08-15  
**Status:** Foundation implementation (prototype mode). Real-money flows remain feature-flagged OFF.  
**Supabase MCP:** Not authenticated in this Cloud Agent session — schema ships as local migration only until live verify.

---

## 1. What already exists (reuse)

| Domain | Reuse |
|--------|--------|
| Auth | `AuthGate`, `AuthSessionController`, Supabase Auth |
| Profiles | `profiles`, `UserProfileService`, account types |
| Business | `businesses`, memberships, media, reviews, menus, verification submissions |
| Professional | `professional_profiles` + media/showcase |
| Events | `community_events`, organizer applications, LIVE geo/presence |
| VUE / posts | `community_news_posts` + `publish_destination` (`vue` / `feed_and_vue`); no separate vue table |
| Engagement | sparks, comments, reposts, saves, `feed_engagements`, `post_impressions`, `feed_interactions` |
| Messaging | Encrypted `fv_msg_*` + legacy DMs |
| Groups | communities, hubs, roles |
| Location | profiles prefs, `business_locations`, event geo, LIVE map |
| Admin | `is_firstvue_admin()`, JWT `app_metadata`, approval hub |
| Notifications | `activity_notifications` + local notifications |
| Analytics | First-party engagement tables (Growth UI still partly placeholder) |
| Design | `FirstVueTheme`, Cormorant/Space Grotesk, gold/teal accents |
| Feature flags | Compile-time `FeatureFlags` / `bool.fromEnvironment` |
| Business SaaS billing (web) | Stripe Checkout Edge Functions + `business_subscriptions` + `FeatureFlags.paymentsEnabled` (default false) |
| Promotion stub | `business_promotions` (featured / sponsored_search / feed) |
| Fee stub | `bookings.platform_fee_cents`, `business_leads.billable_amount_cents` |

---

## 2. What must NOT be duplicated

- Do **not** replace `business_subscriptions` — extend with platform-agnostic `subscription_entitlements` / `subscription_transactions` for Apple/Google/Stripe.
- Do **not** replace `business_promotions` — keep for placement ads; VUE Bounties use `bounty_campaigns`.
- Do **not** create a client-writable wallet balance.
- Do **not** invent a second notification system.
- Do **not** duplicate VUE media storage — submissions reference existing post/media IDs.

---

## 3. Features that must stay free (no accidental paywall)

These remain available without Pro / FirstVue+:

- Account create, profile, follow, like/comment/share
- Post to feed/VUE, discover businesses/events
- Messaging, communities (eligible), event discovery
- Free business tier (create/claim/manage basic profile)
- Free event creation (subject to existing approval rules)

**Existing paid coupling to report (do not expand without approval):**

- Active Stripe `verified` / `pro` currently sets `businesses.verification_status = 'verified'` via webhook.
- Growth screen markets Pro analytics / campaigns; many metrics are still placeholders and must not be sold as live ROI.

---

## 4. Gaps filled by this foundation

| Gap | New foundation |
|-----|----------------|
| Apple/Google IAP entitlements | `subscription_entitlements`, `subscription_transactions` |
| Configurable products/prices | `monetization_products` (no hardcoded prices in UI logic) |
| Server feature flags | `monetization_feature_flags` + client mirrors |
| VUE Bounties | campaigns, requirement versions, applications, submissions |
| Creator reputation | `creator_profiles`, `creator_reputation` (server-controlled) |
| Earnings accounting | immutable `financial_ledger_entries` + read models |
| Affiliates / Share & Earn | programs, attributions, conversions |
| Disputes / risk / admin audit | `campaign_disputes`, `account_risk_states`, `financial_audit_log` |

---

## 5. Attribution policy (documented before implementation)

**Funnel:** VUE → Event → Ticket/eligible conversion → Creator attribution → Pending earnings → Refund window → Available.

**Rules:**

1. Clicks never create permanent earnings.
2. Attribution requires a verified conversion ID from a trusted server path.
3. Default window: configurable per program (`attribution_window_hours`, default 168 = 7 days).
4. Duplicate prevention: unique `(program_id, conversion_external_id)` and unique active attribution per `(buyer_profile_id, event_id)` within window where applicable.
5. Competing sources: **last eligible click within window wins** at conversion time; earlier attributions for the same conversion are marked `superseded`.
6. Self-referral and same-account buyer/creator pairs are flagged `fraud_status = suspected` and do not auto-credit.
7. Refunds/chargebacks move related ledger entries to clawback/pending_reversal states; never delete ledger rows.

---

## 6. Prototype mode defaults

| Flag | Default |
|------|---------|
| `business_subscriptions` | false (mirrors existing payments off) |
| `business_boosts` | false |
| `vue_bounties` | true (architecture + UI explore; no funding) |
| `bounty_funding` | false |
| `creator_payouts` | false |
| `affiliate_rewards` | false |
| `ticketing` | false |
| FirstVue+ | schema-ready product row; inactive |

---

## 7. Payment provider requirements (later)

See `docs/MONETIZATION_PHASE27_REPORT.md` for Apple, Google Play, marketplace payout, and compliance checklist.
