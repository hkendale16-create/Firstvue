# Feed RPC deploy + orphan business media cleanup

## 1. Deploy missing feed RPCs

These exist in `supabase/migrations/20260906_feeds_trending_recommended_interactions.sql`
but were **not** present in the live project during diagnosis (`PGRST202`):

- `fetch_new_feed`
- `fetch_trending_feed`
- `fetch_recommended_feed`
- `record_feed_interaction`

**Action:** paste and run that migration in the Supabase SQL Editor for project
`sdssshegqdwobjelxzkp`.

`fetch_ranked_main_feed` is already live.

## 2. Orphan `business_media` rows (optional cleanup)

All non-demo `business_media` rows with Supabase storage paths were returning
`NoSuchKey` on sign (files missing from the `business-media` bucket).

Client mitigations now cache missing paths and successful signed URLs, but the
DB still references dead objects.

**Safe cleanup options:**

1. Re-upload the missing files to the same paths, **or**
2. Delete only rows whose objects are confirmed missing (do this carefully;
   prefer a manual review in Storage + Table Editor first).

Do **not** purge demo external/picsum rows (`storage_path` starting with `http`).
