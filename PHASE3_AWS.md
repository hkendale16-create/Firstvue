# FirstVue Phase 3 — AWS Integration

Phase 3 adds **AWS SES** for transactional email. **S3 + CloudFront** for media is documented as a follow-up (Phase 3B) — Supabase Storage still works today.

---

## What was added in code

| Area | Change |
|------|--------|
| SQL migration | `supabase/migrations/20260811_phase3_aws_notifications.sql` |
| Edge Function | `supabase/functions/send-email` — sends via AWS SES |
| Email templates | Branded HTML for approvals, inquiries, subscriptions |
| IAM policy sample | `aws/iam-ses-policy.json` |

### Emails that fire automatically (after setup)

| Event | Template |
|-------|----------|
| Business approved / rejected | `business_approved` / `business_rejected` |
| Rental approved / rejected | `rental_approved` / `rental_rejected` |
| Review approved / rejected | `review_approved` / `review_rejected` |
| Professional profile approved / rejected | `professional_approved` / `professional_rejected` |
| New rental inquiry | `rental_inquiry_received` |
| New business submission (admin) | `admin_new_business_submission` |
| Subscription activated | `subscription_activated` |

Flow: **DB trigger → `email_outbox` → Database Webhook → `send-email` → AWS SES**

---

## Step 1 — AWS SES (test sender first)

1. Sign in to [AWS Console](https://console.aws.amazon.com/ses/)
2. **Verified identities → Create identity**
   - Start with your **email address** (sandbox mode) or your **domain** (production)
3. Complete verification (check inbox or add DNS records)
4. **IAM → Users → Create user** (e.g. `firstvue-ses`)
   - Attach policy from `aws/iam-ses-policy.json`
   - Create **Access key** → save `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`

> **Sandbox mode:** SES can only send to verified addresses until you request production access.

---

## Step 2 — Supabase secrets

Dashboard → **Project Settings → Edge Functions → Secrets**

| Secret | Example |
|--------|---------|
| `AWS_ACCESS_KEY_ID` | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | `...` |
| `AWS_REGION` | `us-east-1` |
| `SES_FROM_EMAIL` | `hello@yourdomain.com` (must be verified in SES) |
| `ADMIN_NOTIFY_EMAIL` | your admin inbox for new submissions |
| `EMAIL_WEBHOOK_SECRET` | random string you generate (e.g. `openssl rand -hex 32`) |
| `FIRSTVUE_WEB_URL` | your Netlify URL (for future template links) |

---

## Step 3 — Run SQL migration

In **SQL Editor**, run:

`supabase/migrations/20260811_phase3_aws_notifications.sql`

Verify:

```sql
select tablename from pg_tables where tablename = 'email_outbox';
select count(*) from pg_trigger where tgname like 'enqueue_%';
```

---

## Step 4 — Deploy Edge Function

```powershell
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"; supabase login; supabase link --project-ref sdssshegqdwobjelxzkp; supabase functions deploy send-email
```

---

## Step 5 — Database Webhook (required)

Dashboard → **Database → Webhooks → Create webhook**

| Field | Value |
|-------|--------|
| Name | `send-email-on-outbox-insert` |
| Table | `email_outbox` |
| Events | **Insert** |
| Type | Supabase Edge Function |
| Function | `send-email` |

If using HTTP instead of the built-in Edge Function picker:

- URL: `https://sdssshegqdwobjelxzkp.supabase.co/functions/v1/send-email`
- Header: `x-email-webhook-secret: YOUR_EMAIL_WEBHOOK_SECRET`

---

## Step 6 — Optional: Auth emails through SES

Supabase Dashboard → **Authentication → SMTP Settings**

Use AWS SES SMTP credentials:

| Field | Value |
|-------|--------|
| Host | `email-smtp.us-east-1.amazonaws.com` (match your region) |
| Port | `587` |
| Username | SES SMTP username (from SES → SMTP settings) |
| Password | SES SMTP password |
| Sender email | Same as `SES_FROM_EMAIL` |

Then customize **Auth → Email Templates** with FirstVue branding for confirm/reset emails.

---

## Step 7 — Test

1. In SES sandbox, verify **your test email** as a recipient
2. Approve or reject a test business in admin
3. Check **Table Editor → email_outbox** (status should become `sent`)
4. Check inbox for branded FirstVue email

Manual test insert:

```sql
insert into public.email_outbox (template, recipient_email, payload, idempotency_key)
values (
  'business_approved',
  'you@example.com',
  '{"business_name":"Test Shop"}'::jsonb,
  'manual_test_1'
);
```

---

## Phase 3B — S3 + CloudFront (later)

See **`PHASE3B_AWS_MEDIA.md`** for full setup. Media code supports AWS when built with `--dart-define=FIRSTVUE_AWS_MEDIA=true`.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Outbox stays `pending` | Database webhook not created or wrong function |
| Outbox `skipped` | Missing `ADMIN_NOTIFY_EMAIL` or invalid recipient |
| SES `MessageRejected` | Sender not verified, or recipient not verified in sandbox |
| `Unauthorized` on send-email | Set `EMAIL_WEBHOOK_SECRET` header on webhook |
| No email on approve | Run Phase 3 SQL migration; confirm trigger exists |

---

## Push code changes

```powershell
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"; git add .; git commit -m "Phase 3 AWS SES email notifications"; git push
```

---

## Next after Phase 3

- **Phase 3B:** S3/CloudFront media CDN
- **Phase 4:** Mobile app (iOS/Android from same Flutter repo)
- **Stripe:** Finish dashboard setup when ready (`PHASE2_PAYMENTS.md`)
