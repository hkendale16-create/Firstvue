-- FIRSTVUE private media bucket for rental photos and videos.
-- Run once in Supabase Dashboard > SQL Editor.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rental-media',
  'rental-media',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
)
on conflict (id) do nothing;

-- Files are stored as: <authenticated-user-id>/<unique-file-name>.
-- Drop the policies first so this migration can safely be rerun after a partial SQL Editor run.
drop policy if exists "Rental owners upload media to their own folder" on storage.objects;
drop policy if exists "Rental owners update media in their own folder" on storage.objects;
drop policy if exists "Rental owners delete media in their own folder" on storage.objects;
drop policy if exists "Authenticated users view permitted rental media" on storage.objects;

create policy "Rental owners upload media to their own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'rental-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Rental owners update media in their own folder"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'rental-media'
    and owner_id = auth.uid()::text
  )
  with check (
    bucket_id = 'rental-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Rental owners delete media in their own folder"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'rental-media'
    and owner_id = auth.uid()::text
  );

-- A signed-in user may view their own files or media belonging to an approved rental.
create policy "Authenticated users view permitted rental media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'rental-media'
    and (
      owner_id = auth.uid()::text
      or exists (
        select 1
        from public.rental_media media
        join public.rentals rental on rental.id = media.rental_id
        where media.storage_path = name
          and rental.status = 'approved'
      )
    )
  );
