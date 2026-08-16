# FirstVue — Deploy Checklist (Aug 11, 2026)

Do these in order. Stripe and AWS are **optional** — skip until after web is live.

---

## Step 1 — Web (Netlify) ✅ auto

Code is on `main` (`fdfb490`). If Netlify is connected to GitHub:

1. Open [Netlify Dashboard](https://app.netlify.com) → your FirstVue site → **Deploys**
2. Latest deploy should show **Published** (triggered by your last push)
3. Open the live URL → hard refresh **Ctrl + Shift + R**
4. Smoke test: home, Profile, sign-in, Vue tab

**If deploy failed:** Deploys → failed build → read log. Common fix: first build takes 5–10 min for Flutter download.

**Supabase Auth URLs** (do once you have Netlify URL):

Dashboard → **Authentication → URL Configuration**

| Field | Value |
|-------|--------|
| Site URL | `https://YOUR-SITE.netlify.app` |
| Redirect URLs | `https://YOUR-SITE.netlify.app/**` |

**Google “Continue with Google”** (required for OAuth to finish):

Dashboard → **Authentication → Providers → Google**

| Field | Value |
|-------|--------|
| Enabled | On |
| Client ID | Web client ID from Google Cloud Console |
| Client Secret | Matching Web client secret (must be current) |

Also in [Google Auth Platform → Clients](https://console.cloud.google.com/auth/clients):

1. Authorized JavaScript origins: `https://firstvue.app`, `https://www.firstvue.app`, `https://firstvapp.netlify.app`
2. Authorized redirect URIs: `https://sdssshegqdwobjelxzkp.supabase.co/auth/v1/callback`

If Auth logs show `invalid_client` / `Unable to exchange external code`, the Client Secret in Supabase is wrong or was rotated — paste the current secret from Google Cloud and save.

---

## Step 2 — Supabase SQL (run in order)

Open [SQL Editor](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new).

Run each file **once**, in this order. Skip any you already ran.

### Core (if not applied yet)

1. `supabase/apply_pending_migrations.sql`
2. `supabase/migrations/20260811_messaging_and_comments.sql`
3. `supabase/migrations/20260811_professional_media_availability.sql`
4. `supabase/migrations/20260811_professional_showcase.sql`
5. `supabase/migrations/20260811_social_discovery_monetization.sql`
6. `supabase/migrations/20260811_ai_commerce_owner_connections.sql`
7. `supabase/migrations/20260811_phase1_security_hardening.sql`

### Phase 3 — Email (optional until AWS SES configured)

8. `supabase/migrations/20260811_phase3_aws_notifications.sql`

Then create **Database Webhook**: `email_outbox` INSERT → `send-email` function (see `PHASE3_AWS.md`).

### Phase 3B — Media provider column

9. `supabase/migrations/20260811_phase3b_aws_media_storage.sql`

### Phase 2 — Stripe (skip for now)

10. `supabase/migrations/20260811_phase2_stripe_payments.sql` — only when enabling Stripe

### Verify

```sql
select tablename from pg_tables
where tablename in ('email_outbox', 'direct_messages', 'feed_engagements')
order by tablename;

select column_name from information_schema.columns
where table_name = 'business_media' and column_name = 'storage_provider';
```

---

## Step 3 — Mobile APK (local)

### One-time: Windows Developer Mode (symlinks)

```powershell
start ms-settings:developers
```

Turn on **Developer Mode**, then restart terminal.

### Build

```powershell
$env:Path = "C:\Users\User1\develop\flutter\bin;" + $env:Path
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"
flutter pub get
flutter build apk --release
```

APK output:

`build\app\outputs\flutter-apk\app-release.apk`

Copy to phone (USB/email/Drive) → install → allow unknown sources if prompted.

**iOS:** requires Mac + Xcode — see `PHASE4_MOBILE.md`

---

## Step 4 — AWS (when ready)

| Doc | What |
|-----|------|
| `PHASE3_AWS.md` | SES email + `send-email` function deploy |
| `PHASE3B_AWS_MEDIA.md` | S3 + CloudFront + `--dart-define=FIRSTVUE_AWS_MEDIA=true` |

No AWS keys in Flutter. All secrets go in Supabase Edge Function secrets.

---

## Step 5 — Stripe (add-on after live)

Follow `PHASE2_PAYMENTS.md` when you want Verified/Pro subscriptions.

---

## Admin access reminder

After Phase 1 SQL + JWT refresh:

1. Supabase → **Authentication → Users** → your user → **App Metadata**
2. `{ "firstvue_admin": true }`
3. Sign out and back in on FirstVue

---

## Quick links

| Service | URL |
|---------|-----|
| GitHub | https://github.com/hkendale16-create/Firstvue |
| Supabase project | https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp |
| Netlify | https://app.netlify.com |
