-- Allows signed-in users to read media records for approved rentals.
-- Run once in Supabase Dashboard > SQL Editor before testing rental media.

drop policy if exists "Authenticated users view approved rental media records" on public.rental_media;

create policy "Authenticated users view approved rental media records"
  on public.rental_media for select to authenticated
  using (
    exists (
      select 1
      from public.rentals rental
      where rental.id = rental_id
        and (rental.status = 'approved' or rental.owner_id = auth.uid())
    )
  );
