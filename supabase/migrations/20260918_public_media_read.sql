-- =============================================================================
-- Public read for profile photos / VUE / post media.
--
-- Profile avatars and gallery rows were authenticated-only, so signed URL
-- creation and CanvasKit fetches failed for public surfaces. Storage SELECT
-- for the social media buckets was also authenticated-only (policies named
-- "Public reads..." still used TO authenticated).
--
-- Does not open fv-msg-media (encrypted DMs).
-- =============================================================================

-- Table: anyone can read profile gallery/avatar/cover rows (no PII in this table).
drop policy if exists "Public read profile media" on public.profile_media;
drop policy if exists "Authenticated users read profile media" on public.profile_media;
create policy "Public read profile media"
  on public.profile_media for select to anon, authenticated
  using (true);

drop policy if exists "Authenticated users view approved business media records"
  on public.business_media;
drop policy if exists "Public view approved business media records"
  on public.business_media;
create policy "Public view approved business media records"
  on public.business_media for select to anon, authenticated
  using (
    exists (
      select 1 from public.businesses business
      where business.id = business_id
        and business.status = 'approved'
    )
  );

-- Storage objects: allow creating/fetching signed URLs for social buckets.
drop policy if exists "Authenticated users read profile media files" on storage.objects;
drop policy if exists "Public read profile media files" on storage.objects;
create policy "Public read profile media files"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'profile-media');

drop policy if exists "Authenticated users view approved business media files"
  on storage.objects;
drop policy if exists "Public view approved business media files"
  on storage.objects;
create policy "Public view approved business media files"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'business-media'
    and exists (
      select 1
      from public.business_media media
      join public.businesses business on business.id = media.business_id
      where media.storage_path = name
        and business.status = 'approved'
    )
  );

drop policy if exists "Public reads approved news post media files" on storage.objects;
create policy "Public reads approved news post media files"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'community-news-media'
    and exists (
      select 1
      from public.community_news_post_media media
      join public.community_news_posts post on post.id = media.post_id
      where media.storage_path = name
        and post.status = 'approved'
    )
  );

drop policy if exists "Authenticated users view approved professional portfolio files"
  on storage.objects;
drop policy if exists "Public view approved professional portfolio files"
  on storage.objects;
create policy "Public view approved professional portfolio files"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'professional-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.professional_media media
        join public.professional_profiles professional
          on professional.id = media.professional_profile_id
        where media.storage_path = name
          and (
            professional.status = 'approved'
            or professional.profile_id = auth.uid()
          )
      )
    )
  );

notify pgrst, 'reload schema';
