-- Allows a business submitter to manage their own profile details and location.
-- Run once in Supabase Dashboard > SQL Editor.

drop policy if exists "Owners update their own businesses" on public.businesses;
drop policy if exists "Owners manage their own business locations" on public.business_locations;

create policy "Owners update their own businesses"
  on public.businesses for update to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

create policy "Owners manage their own business locations"
  on public.business_locations for all to authenticated
  using (exists (select 1 from public.businesses business where business.id = business_id and business.created_by = auth.uid()))
  with check (exists (select 1 from public.businesses business where business.id = business_id and business.created_by = auth.uid()));
