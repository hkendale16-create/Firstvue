# FirstVue Phase 3B — AWS S3 + CloudFront Media

Phase 3B adds **optional** AWS media storage. Until you enable it, FirstVue keeps using **Supabase Storage** (no breakage).

---

## Architecture

```
Flutter upload  →  media-storage Edge Function  →  S3 presigned PUT
Flutter read    →  media-storage Edge Function  →  S3 presigned GET or CloudFront URL
DB row          →  storage_path + storage_provider ('supabase' | 's3')
```

Enable at build time:

```bash
flutter build web --dart-define=FIRSTVUE_AWS_MEDIA=true
```

Netlify: add to `scripts/build-web.sh` when AWS is ready.

---

## Step 1 — AWS S3 bucket

1. **S3 → Create bucket** (e.g. `firstvue-media-prod`)
2. Block all public access (keep private)
3. Create IAM user `firstvue-media` with `aws/iam-s3-media-policy.json` (replace bucket name)
4. Save access keys

Object key layout (matches Supabase paths):

```
business-media/{user_id}/{timestamp}_{index}_{filename}
rental-media/{user_id}/...
professional-media/{user_id}/...
```

---

## Step 2 — CloudFront (optional, recommended)

1. Create **CloudFront distribution** with S3 origin (OAC)
2. Note domain: `d1234abcd.cloudfront.net`
3. Approved/public feed media can be served from CDN without per-request S3 signing

Set Supabase secret:

| Secret | Value |
|--------|--------|
| `CLOUDFRONT_DOMAIN` | `d1234abcd.cloudfront.net` |

---

## Step 3 — Supabase secrets

| Secret | Value |
|--------|--------|
| `S3_MEDIA_BUCKET` | `firstvue-media-prod` |
| `AWS_ACCESS_KEY_ID` | IAM key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret |
| `AWS_REGION` | `us-east-1` |
| `CLOUDFRONT_DOMAIN` | optional CDN domain |

(Reuse same AWS keys as SES if the IAM user has both policies.)

---

## Step 4 — SQL migration

Run in Supabase SQL Editor:

`supabase/migrations/20260811_phase3b_aws_media_storage.sql`

Adds `storage_provider` column to media tables (defaults to `supabase`).

---

## Step 5 — Deploy Edge Function

```powershell
Set-Location "C:\Users\User1\Documents\Codex\2026-08-10\now-inspect-the-existing-firstvue-repository-2\firstvue"; supabase functions deploy media-storage
```

---

## Step 6 — Enable in builds

**Local / Netlify** — only after S3 is configured:

```bash
--dart-define=FIRSTVUE_AWS_MEDIA=true
```

New uploads go to S3. Existing rows with `storage_provider = 'supabase'` still read from Supabase.

---

## Migrating existing media (later)

1. Script: list Supabase Storage objects → copy to S3 with same key prefix
2. Update `storage_provider = 's3'` in DB rows
3. Verify feed + business profiles load from CDN

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Upload still uses Supabase | Build without `FIRSTVUE_AWS_MEDIA=true` |
| 501 from media-storage | S3 secrets not set |
| 403 on read | Business/rental not approved and user is not owner |
| Old photos missing after switch | Old rows still `supabase`; run backfill or keep flag off |

---

## Stripe

Payments remain optional — enable later with `PHASE2_PAYMENTS.md` after deploy.
