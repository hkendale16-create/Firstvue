# Apply pending Supabase migrations

Project: `sdssshegqdwobjelxzkp`

## Steps

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
