# FirstVue Phase 1 Security — Setup Guide

Phase 1 hardens admin access, profile escalation, HTTP headers, auth UX, and legal pages.

## What was added in code

| Area | Change |
|------|--------|
| SQL migration | `supabase/migrations/20260811_phase1_security_hardening.sql` |
| Admin checks | `lib/services/admin_auth_service.dart` |
| Admin UI gate | `lib/widgets/admin_gate.dart` |
| Profile | Admin rows hidden unless you are admin |
| Auth | 8-char passwords, forgot-password email, safe profile bootstrap |
| Legal | Privacy + Terms screens in Profile → Legal |
| Netlify | Security headers in `netlify.toml` |

---

## Step 1 — Run SQL in Supabase (required)

Open **Supabase → SQL Editor** and run these files **in order** if not already applied:

1. `supabase/apply_pending_migrations.sql`
2. `supabase/migrations/20260811_messaging_and_comments.sql`
3. `supabase/migrations/20260811_phase1_security_hardening.sql`

Verify:

```sql
select public.is_firstvue_admin();
-- should return false when run as SQL editor (no auth context)

select policyname from pg_policies where tablename = 'profiles';
-- should include Users read/insert/update their own profile
```

---

## Step 2 — Make yourself admin (required for approvals)

**Preferred (JWT claim):**

1. Supabase → **Authentication → Users**
2. Click your user → **Edit user**
3. Under **App Metadata**, set:

```json
{
  "firstvue_admin": true
}
```

4. Sign out and sign back in on FirstVue so the JWT refreshes.

**Alternative (legacy):** In SQL Editor as service role:

```sql
update public.profiles
set account_type = 'admin'
where id = 'YOUR-USER-UUID';
```

> Users can **no longer** set `account_type = 'admin'` from the app. The migration blocks self-escalation.

---

## Step 3 — Supabase Auth dashboard settings

In **Authentication → Providers → Email**:

- [ ] Enable **Confirm email** (recommended for production)
- [ ] Minimum password length **8** (matches app)
- [ ] Configure **Site URL** and **Redirect URLs** to your Netlify domain

In **Authentication → URL Configuration**:

- Site URL: `https://YOUR-SITE.netlify.app`
- Redirect URLs: `https://YOUR-SITE.netlify.app/**`

---

## Step 4 — Deploy app changes

```powershell
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"; git add .; git commit -m "Phase 1 security hardening"; git push
```

Wait for Netlify **Published**, then hard refresh (**Ctrl + Shift + R**).

---

## Step 5 — Smoke test checklist

- [ ] Sign up / sign in works
- [ ] Forgot password sends email
- [ ] Non-admin account does **not** see admin rows in Profile
- [ ] Admin account sees Professional / Business / Review / Rental approvals
- [ ] Privacy policy and Terms open from Profile
- [ ] Attempting `account_type: admin` via API/client fails (RLS + trigger)

---

## Security model (remember)

| Layer | Responsibility |
|-------|----------------|
| Flutter app | UX, hiding admin nav, input validation |
| Supabase RLS | Real authorization for every table |
| JWT app_metadata | Trusted admin flag (`firstvue_admin`) |
| Trigger | Blocks profile self-escalation to admin |
| Netlify headers | Browser-level protections |

Never put Stripe secrets, AWS keys, or Supabase **service_role** keys in Flutter code.

---

## Next phase preview

Phase 2: Stripe subscriptions + webhooks (Supabase Edge Functions or AWS Lambda).
