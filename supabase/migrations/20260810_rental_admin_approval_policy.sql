-- FirstVue admin access for reviewing rental listings.
-- This grants access only to profiles whose account_type is already 'admin'.
-- Run once in Supabase Dashboard > SQL Editor.

drop policy if exists "FirstVue admins manage rentals" on public.rentals;
drop policy if exists "FirstVue admins manage rental media records" on public.rental_media;
drop policy if exists "FirstVue admins view rental media files" on storage.objects;

create policy "FirstVue admins manage rentals"
  on public.rentals for all to authenticated
  using (
    exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  );

create policy "FirstVue admins manage rental media records"
  on public.rental_media for all to authenticated
  using (
    exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  );

create policy "FirstVue admins view rental media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'rental-media'
    and exists (
      select 1 from public.profiles profile
      where profile.id = auth.uid() and profile.account_type = 'admin'
    )
  );
