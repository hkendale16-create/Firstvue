# FirstVue demo seed (25 people)

Temporary pack so Explore, Feeds, VUE, businesses, and events look fully populated.
All rows are marked `is_demo = true` and usernames start with `fvdemo_`.

> **Important:** Refreshing the app does **not** create demo people. You must
> run the SQL seed in Supabase once (steps below). After that, hard-refresh.

## Auto-purge after 10 real signups

Once **10 real (non-demo) users** have signed up, Supabase automatically deletes
the entire demo pack via `fv_maybe_purge_demo_pack()` (see migration
`20261017_demo_auto_purge_after_ten_users.sql`).

While demos still exist, the auth screen shows a **Demo accounts available**
banner with login credentials. After purge, that banner disappears.

Public status RPC (anon + authenticated): `fv_demo_accounts_status()`.

## What you get

| Kind | Count | Notes |
| --- | --- | --- |
| People | 25 | Public profiles + avatars + gallery shots |
| Posts | ~43 | Feed + VUE destinations with images |
| Businesses | 5 | Verified, labeled `[DEMO]` |
| Events | 3 | Future dates, labeled `[DEMO]` |

Demo login password for every seeded auth user (optional): `FirstVueDemo!25`  
Emails: `fvdemo01@firstvue.demo` … `fvdemo25@firstvue.demo`

## Apply (seed)

1. Open [Supabase SQL Editor](https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new)
2. Paste **entire** `supabase/APPLY_DEMO_SEED.sql`
3. Run
4. Confirm the verification query shows ~25 people, ~43 posts, 5 businesses, 3 events
5. (Recommended) Also run `supabase/APPLY_PROFILE_MEDIA_CAPTIONS.sql` so Explore orders newest people first
6. Refresh the live site (hard refresh on phone)

Also ship the app build that includes **external media URL** support (`MediaStorageProvider.external`), otherwise demo images will not resolve on VUE/feeds.

## Purge (delete when done reviewing)

Automatic: happens when real user count reaches 10.

Manual:

1. Open the SQL Editor again
2. Paste **entire** `supabase/APPLY_DEMO_PURGE.sql` (or `select public.fv_purge_demo_pack();`)
3. Run
4. Confirm remaining demo counts are `0`

Or tell the cloud agent “delete the demo profiles” after you have looked around.

## Safety

- Purge only deletes `is_demo` / `fvdemo_%` rows
- Real accounts are not touched
- Businesses and events use a `[DEMO]` name prefix in the UI
