-- FirstVue admin approval access for business submissions.
-- Run once in Supabase Dashboard > SQL Editor.

drop policy if exists "FirstVue admins manage businesses" on public.businesses;
drop policy if exists "FirstVue admins manage business submissions" on public.business_verification_submissions;

create policy "FirstVue admins manage businesses"
  on public.businesses for all to authenticated
  using (exists (select 1 from public.profiles profile where profile.id = auth.uid() and profile.account_type = 'admin'))
  with check (exists (select 1 from public.profiles profile where profile.id = auth.uid() and profile.account_type = 'admin'));

create policy "FirstVue admins manage business submissions"
  on public.business_verification_submissions for all to authenticated
  using (exists (select 1 from public.profiles profile where profile.id = auth.uid() and profile.account_type = 'admin'))
  with check (exists (select 1 from public.profiles profile where profile.id = auth.uid() and profile.account_type = 'admin'));
