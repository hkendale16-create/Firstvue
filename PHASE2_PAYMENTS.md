# FirstVue Phase 2 — Stripe Payments Setup

Phase 2 adds **Verified** ($9.99/mo) and **Pro** ($29.99/mo) subscriptions via **Stripe Checkout** and **Supabase Edge Functions**.

---

## Architecture

```
Flutter app  →  create-checkout-session (Edge Function)
                      ↓
                 Stripe Checkout (hosted)
                      ↓
                 stripe-webhook (Edge Function)
                      ↓
           business_subscriptions + verification_status
```

Secrets stay on Supabase — never in Flutter code.

---

## Step 1 — Stripe Dashboard (test mode first)

1. Create account at [stripe.com](https://stripe.com)
2. **Products → Add product**
   - **Verified** — recurring $9.99/month → copy **Price ID** (`price_...`)
   - **Pro** — recurring $29.99/month → copy **Price ID**
3. **Developers → API keys** — copy **Secret key** (`sk_test_...`)
4. **Developers → Webhooks → Add endpoint**
   - URL: `https://sdssshegqdwobjelxzkp.supabase.co/functions/v1/stripe-webhook`
   - Events:
     - `checkout.session.completed`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
   - Copy **Signing secret** (`whsec_...`)

---

## Step 2 — Supabase secrets

Supabase Dashboard → **Project Settings → Edge Functions → Secrets**

| Secret | Value |
|--------|--------|
| `STRIPE_SECRET_KEY` | `sk_test_...` |
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` |
| `STRIPE_PRICE_VERIFIED` | `price_...` |
| `STRIPE_PRICE_PRO` | `price_...` |
| `FIRSTVUE_WEB_URL` | `https://YOUR-SITE.netlify.app` |

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected for Edge Functions.

---

## Step 3 — Run SQL migration

In **SQL Editor**, run:

`supabase/migrations/20260811_phase2_stripe_payments.sql`

This adds:
- Unique subscription per business
- Webhook idempotency table
- `sync_business_subscription_from_stripe()` RPC

---

## Step 4 — Deploy Edge Functions

Install [Supabase CLI](https://supabase.com/docs/guides/cli), then:

```powershell
cd "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"
supabase login
supabase link --project-ref sdssshegqdwobjelxzkp
supabase functions deploy create-checkout-session
supabase functions deploy stripe-webhook
```

---

## Step 5 — Deploy Flutter app

```powershell
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"
flutter pub get
git add .
git commit -m "Phase 2 Stripe subscription billing"
git push
```

---

## Step 6 — Test flow

1. Sign in on live site
2. Profile → **Growth, plans & analytics**
3. Select your business → **Upgrade with Stripe** on Verified or Pro
4. Use Stripe test card: `4242 4242 4242 4242`, any future date, any CVC
5. After redirect, you should see “Subscription activated”
6. Verify in Supabase **Table Editor → business_subscriptions**

---

## Plans

| Plan | Price | Stripe | DB `plan` value |
|------|-------|--------|-----------------|
| Basic | Free | — | (no row) |
| Verified | $9.99/mo | STRIPE_PRICE_VERIFIED | `verified` |
| Pro | $29.99/mo | STRIPE_PRICE_PRO | `pro` |

Active Verified/Pro sets `businesses.verification_status = 'verified'`.

---

## Going live (production)

1. Switch Stripe to **Live mode**
2. Create live products/prices
3. Update Supabase secrets with live keys + live webhook signing secret
4. Redeploy Edge Functions
5. Complete Stripe business verification

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| “STRIPE_PRICE_VERIFIED is not configured” | Add secrets in Supabase, redeploy function |
| Checkout works but plan not updated | Check webhook logs in Stripe; verify `stripe-webhook` deployed |
| 401 on checkout | User must be signed in; business must be owned by user |
| Webhook 400 signature | Wrong `STRIPE_WEBHOOK_SECRET` |

---

## Next (Phase 3 preview)

- AWS SES for receipt emails
- Stripe Customer Portal for cancel/manage
- Promoted placement one-time payments
