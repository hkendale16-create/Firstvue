-- Allows a rental owner to read and mark inquiries on their own rental listings.
-- Run once in Supabase Dashboard > SQL Editor.

drop policy if exists "Rental owners read inquiries" on public.rental_inquiries;
drop policy if exists "Rental owners update inquiries" on public.rental_inquiries;

create policy "Rental owners read inquiries"
  on public.rental_inquiries for select to authenticated
  using (
    exists (
      select 1 from public.rentals rental
      where rental.id = rental_id and rental.owner_id = auth.uid()
    )
  );

create policy "Rental owners update inquiries"
  on public.rental_inquiries for update to authenticated
  using (
    exists (
      select 1 from public.rentals rental
      where rental.id = rental_id and rental.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.rentals rental
      where rental.id = rental_id and rental.owner_id = auth.uid()
    )
  );
