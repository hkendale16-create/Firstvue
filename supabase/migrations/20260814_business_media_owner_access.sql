-- Let business owners view/upload media immediately — no business approval required for media.
-- Expands supported MIME types for photos and videos.

update storage.buckets
set
  allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif',
    'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
    'video/x-matroska', 'video/x-m4v'
  ]
where id = 'business-media';

drop policy if exists "Owners view their business media files" on storage.objects;
create policy "Owners view their business media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'business-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.business_media media
        join public.businesses business on business.id = media.business_id
        where media.storage_path = name
          and business.created_by = auth.uid()
      )
    )
  );

drop policy if exists "Owners read their business media records" on public.business_media;
create policy "Owners read their business media records"
  on public.business_media for select to authenticated
  using (
    exists (
      select 1 from public.businesses business
      where business.id = business_id and business.created_by = auth.uid()
    )
  );
