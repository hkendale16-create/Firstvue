-- Community group profile images already live on public.communities.image_url /
-- cover_url (see 20260821_social_platform_upgrade.sql).
--
-- This migration documents that no schema change is required for group avatars.
-- Client uploads store a signed/read URL in communities.image_url.
--
-- Unique membership/follow constraints already exist as composite primary keys:
--   community_members (community_id, profile_id)
--   community_follows (community_id, profile_id)
--
-- Preserve business_media_one_avatar_idx / professional_media_one_avatar_idx —
-- client code now deletes-by-role before insert (and retries on 23505).

select 1;
