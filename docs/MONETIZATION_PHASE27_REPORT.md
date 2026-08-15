# Monetization + VUE Bounties — Phase 27 Stop Report

**Date:** 2026-08-15  
**Branch:** `cursor/monetization-vue-bounties-foundation-240e`  
**Mode:** Architecture + UI foundation only. **No live payments.**  
**Git push:** Held per explicit request — review before push.

---

## 1. What was implemented

- Phase 1 architecture audit (`docs/MONETIZATION_ARCHITECTURE_AUDIT.md`)
- Supabase migration for monetization / bounties / ledger / affiliates / disputes / risk / admin overview
- Central product + fee config (`monetization_products`, `lib/config/monetization_config.dart`)
- Feature flags (compile-time + server table) for subscriptions, boosts, bounties, funding, payouts, affiliates, ticketing
- Platform-agnostic subscription entitlements / transactions (Apple/Google/Stripe-ready)
- VUE Bounty campaigns (fixed / performance / hybrid), versioned requirements, applications, submissions
- Creator profile + reputation foundation (server-controlled reputation writes)
- Immutable financial ledger + earnings read model (not a wallet)
- Share & Earn affiliate schema + attribution policy docs
- Sponsored disclosure badge
- UI: bounty discovery/detail, creator earnings, business campaign dashboard, admin financial overview
- Settings navigation wiring; Growth screen prices read from product catalog
- Contract tests for flags, money math, migration presence, CTA gating

## 2. Database changes

New migration: `supabase/migrations/20261010_monetization_vue_bounties_foundation.sql`

Tables include: `monetization_products`, `monetization_feature_flags`, `subscription_entitlements`, `subscription_transactions`, `creator_profiles`, `creator_reputation`, `bounty_campaigns`, `bounty_requirement_versions`, `bounty_applications`, `bounty_submissions`, `bounty_campaign_metrics`, `financial_ledger_entries`, `payout_records`, `affiliate_programs`, `affiliate_attributions`, `affiliate_conversions`, `campaign_disputes`, `account_risk_states`, `financial_audit_log`.

View: `creator_earnings_balances`  
RPCs: `fv_ensure_creator_profile`, `fv_apply_to_bounty`, `fv_withdraw_bounty_application`, `fv_accept_bounty_application`, `fv_get_creator_earnings_summary`, `fv_list_nearby_bounties`, `fv_is_monetization_flag_enabled`, `fv_admin_financial_overview`, `fv_owns_business`.

**Not applied to live Supabase in this session** (MCP auth unavailable). Apply migration in Dashboard/CLI after review.

## 3. RLS / security changes

- RLS enabled on all new tables
- Clients: read own/relevant rows; draft bounty create/update; apply/withdraw via RPC
- **No client INSERT/UPDATE** on ledger, payouts, entitlements, transactions, reputation
- Triggers block client financial writes; lock requirement versions after acceptance; protect campaign money/funding fields
- Admin financial overview requires `is_firstvue_admin()`

## 4. UI changes

- Settings → VUE Bounties, Creator earnings, Campaign dashboard (when `vueBountiesEnabled`)
- Settings → Admin → Financial controls
- Growth screen: catalog-driven Verified/Pro price labels; link to campaign dashboard
- New screens/widgets listed above
- No payment buttons shown when funding/payout/subscription flags are off

## 5. Existing systems reused

Auth, profiles, businesses, events, VUE/`community_news_posts`, engagement analytics, notifications, admin JWT/`is_firstvue_admin`, Stripe Checkout path + `business_subscriptions`, `FeatureFlags` pattern, design system, media storage (submissions reference existing posts — no duplicate video storage).

## 6. Features currently enabled (prototype)

- Free consumers + free businesses + free events (unchanged)
- VUE Bounty architecture + discovery/earnings/campaign UI (`vue_bounties` default **true**)
- Creator profile/reputation foundation
- Analytics tables / campaign metrics shells (zeros until wired)

## 7. Features behind flags (default OFF)

| Flag | Default |
|------|---------|
| `business_subscriptions` / `FIRSTVUE_PAYMENTS` | false |
| `business_boosts` | false |
| `bounty_funding` | false |
| `creator_payouts` | false |
| `affiliate_rewards` | false |
| `ticketing` | false |
| FirstVue+ product | inactive, unpriced |

## 8. Payment provider requirements (next)

- Finalize marketplace payout provider (Connect-like or equivalent) before any creator cash out
- Decide Stripe vs hybrid for **web** business subscriptions (existing Checkout) vs mobile
- Tax/1099, KYC, refunds, disputes, chargebacks workflows
- Never describe funds as legal “escrow” unless the provider+legal structure supports it

## 9. Apple billing requirements

- Digital subscriptions/features on iOS must use **StoreKit / In-App Purchase**, not Apple Pay as a substitute
- Store product IDs in `monetization_products.apple_product_id`
- Server-side receipt/JWS verification → write `subscription_transactions` + `subscription_entitlements`
- Do not unlock Pro from client-only purchase success

## 10. Google Play billing requirements

- Use Google Play Billing for digital subscriptions on Android
- Store product IDs in `monetization_products.google_product_id`
- Server verification (Play Developer API) as source of truth for entitlements
- Handle acknowledgement, renewals, grace periods, refunds

## 11. Marketplace payout requirements

- Compliant payout rail for creators (identity verification, tax forms as required)
- Immutable ledger → available balance → payout_records
- Holdbacks for refund/chargeback windows
- No unrestricted stored-value wallet / cash-out without provider

## 12. Remaining compliance / security concerns

- Supabase MCP not authenticated here — live RLS verification pending
- Growth “performance” metrics still placeholders — do not market as live ROI
- Existing Stripe path couples paid Verified/Pro to `verification_status` — do not expand paywalls without approval
- `activity_notifications` historically lacks a broad INSERT policy; bounty accept uses SECURITY DEFINER
- Need remote kill-switch ops process for `monetization_feature_flags`
- Fraud signals are state containers only — no auto-ban
- Legal copy for sponsored disclosures, creator agreements, business campaign terms still needed
- Web vs native billing policy must be documented for App Review

## 13. Recommended next implementation phase

1. Apply migration to staging Supabase; run advisor + RLS probe as normal user  
2. Wire entitlement sync from existing Stripe webhook into `subscription_entitlements`  
3. Prototype-only “activate campaign” path that **does not** move money (status transitions for UX QA)  
4. Choose payout provider; design funding authorization API behind `bounty_funding`  
5. Implement StoreKit + Play Billing entitlement verification services  
6. Explicit approval gate before enabling any real-money flag  

**STOP — wait for explicit approval before enabling real-money functionality or pushing to remote (per task instruction).**
