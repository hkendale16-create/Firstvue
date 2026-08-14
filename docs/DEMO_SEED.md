# FirstVue demo seed (25 people)

Temporary pack so Explore, Feeds, VUE, businesses, and events look fully populated.
All rows are marked `is_demo = true` and usernames start with `fvdemo_`.

## What you get

| Kind | Count | Notes |
| --- | --- | --- |
| People | 25 | Public profiles + avatars + gallery shots |
| Posts | ~43 | Feed + VUE destinations with images |
| Businesses | 5 | Approved, labeled `[DEMO]` |
| Events | 3 | Future dates, labeled `[DEMO]` |

Demo login password for every seeded auth user (optional): `FirstVueDemo!25`  
Emails: `fvdemo01@firstvue.demo` … `fvdemo25@firstvue.demo`

## Apply (seed)

1. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new)
2. Paste **entire** `supabase/APPLY_DEMO_SEED.sql`
3. Run
4. Confirm the verification query shows ~25 people, ~43 posts, 5 businesses, 3 events
5. Refresh the live site (hard refresh on phone)

Also ship the app build that includes **external media URL** support (`MediaStorageProvider.external`), otherwise demo images will not resolve on VUE/feeds.

## Purge (delete when done reviewing)

1. Open the SQL Editor again
2. Paste **entire** `supabase/APPLY_DEMO_PURGE.sql`
3. Run
4. Confirm remaining demo counts are `0`

Or tell the cloud agent “delete the demo profiles” after you have looked around.

## Safety

- Purge only deletes `is_demo` / `fvdemo_%` rows
- Real accounts are not touched
- Businesses and events use a `[DEMO]` name prefix in the UI
