# Apply pending Supabase migrations

Project: `sdssshegqdwobjelxzkp`

## Demo seed (temporary populated site)

To fill Explore / Feeds / VUE with **25 labeled demo people** plus posts,
businesses, and events:

1. Run `supabase/APPLY_DEMO_SEED.sql` in the SQL Editor
2. See `docs/DEMO_SEED.md` for details and purge steps (`APPLY_DEMO_PURGE.sql`)


If you are **signed in** and Explore/Feeds fail, Home posts fail, or photos
fail while **signed-out** pages still work, run this in the SQL Editor:

1. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new)
2. Paste `supabase/APPLY_FIX_COMMUNITY_RLS_RECURSION.sql`
3. Click **Run** (safe to re-run)

This removes `42P17 infinite recursion detected in policy for relation
"community_members"` which blocks authenticated `community_news_posts` and
`communities` reads.

## Critical for photos (signed-in blank images)

If profile **names** load but **pictures/avatars** do not, run this first in the SQL Editor:

1. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new)
2. Paste the full contents of `supabase/APPLY_PUBLIC_MEDIA_READ.sql`
3. Click **Run** (safe to re-run)

This restores `SELECT` on social media tables and storage buckets so
`createSignedUrl` works for avatars, VUE, posts, and business media.
Without it, the app shows names from Postgres but empty image placeholders.

## Steps (other pending migrations)

1. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new)
2. Open `supabase/apply_pending_migrations.sql` in this project
3. Paste the full file into the SQL Editor
4. Click **Run**
5. Confirm success (no errors). Safe to rerun — uses `if not exists` / `drop policy if exists`

## What this enables

| Migration section | Features unlocked |
|-------------------|-------------------|
| professional_media_availability | Portfolio uploads, availability, booking URL |
| professional_showcase | Social links, post links, catalog |
| social_discovery_monetization | Vue feed columns, `feed_engagements`, anon media reads |
| ai_commerce_owner_connections | AI search ranking fields, bookings, leads, discovery view |

## Verify

Run in SQL Editor after apply:

```sql
select column_name
from information_schema.columns
where table_name = 'businesses'
  and column_name in ('popularity_score', 'available_today', 'minimum_price_cents');

select to_regclass('public.feed_engagements');
select to_regclass('public.business_discovery_view');
```

All should return rows.

## Auth redirect (for deploy)

After you know your production URL, add it in:

**Supabase → Authentication → URL Configuration → Redirect URLs**

Example: `https://your-firstvue-domain.com/**`

---

## New migration (messaging, comments, onboarding support)

After the batch above, also run:

`supabase/migrations/20260811_messaging_and_comments.sql`

This adds direct messaging threads, Vue feed comments, and is required before Messages / Comment features work in the app.
