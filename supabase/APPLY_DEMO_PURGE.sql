-- =============================================================================
-- FirstVue DEMO PURGE — removes the fvdemo_* pack only
-- Paste into Supabase SQL Editor and Run.
-- Dashboard: https://supabase.com/dashboard/project/sdssshegqdwobjelxzkp/sql/new
-- =============================================================================

begin;

-- Collect demo profile ids
create temporary table _fv_demo_purge on commit drop as
select id
from public.profiles
where coalesce(is_demo, false) = true
   or username like 'fvdemo_%';

-- Explicit cleanup first (in case cascades differ by environment)
delete from public.community_news_post_media
where post_id in (
  select id from public.community_news_posts
  where coalesce(is_demo, false) = true
     or author_id in (select id from _fv_demo_purge)
);

delete from public.community_news_posts
where coalesce(is_demo, false) = true
   or author_id in (select id from _fv_demo_purge);

delete from public.community_events
where coalesce(is_demo, false) = true
   or organizer_id in (select id from _fv_demo_purge);

delete from public.business_media
where business_id in (
  select id from public.businesses
  where coalesce(is_demo, false) = true
     or created_by in (select id from _fv_demo_purge)
);

delete from public.business_locations
where business_id in (
  select id from public.businesses
  where coalesce(is_demo, false) = true
     or created_by in (select id from _fv_demo_purge)
);

delete from public.business_memberships
where profile_id in (select id from _fv_demo_purge)
   or business_id in (
     select id from public.businesses
     where coalesce(is_demo, false) = true
        or created_by in (select id from _fv_demo_purge)
   );

delete from public.businesses
where coalesce(is_demo, false) = true
   or created_by in (select id from _fv_demo_purge);

delete from public.profile_media
where profile_id in (select id from _fv_demo_purge);

delete from public.community_organizers
where profile_id in (select id from _fv_demo_purge);

-- Auth delete cascades remaining profile rows
delete from auth.identities
where user_id in (select id from _fv_demo_purge);

delete from auth.users
where id in (select id from _fv_demo_purge);

commit;

select
  (select count(*) from public.profiles where coalesce(is_demo, false) or username like 'fvdemo_%') as remaining_demo_people,
  (select count(*) from public.community_news_posts where coalesce(is_demo, false)) as remaining_demo_posts,
  (select count(*) from public.businesses where coalesce(is_demo, false)) as remaining_demo_businesses,
  (select count(*) from public.community_events where coalesce(is_demo, false)) as remaining_demo_events;
