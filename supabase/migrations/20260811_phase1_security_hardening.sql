-- Phase 1 security hardening for FirstVue.
-- Run in Supabase SQL Editor after prior migrations.
-- Safe to rerun: uses drop/if exists patterns.

-- ---------------------------------------------------------------------------
-- 1. Admin detection (JWT app_metadata OR legacy profiles.account_type)
--    Set admin in Dashboard: Authentication → Users → user → app_metadata:
--    { "firstvue_admin": true }
-- ---------------------------------------------------------------------------
create or replace function public.is_firstvue_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'firstvue_admin')::boolean, false)
      or coalesce(auth.jwt() -> 'app_metadata' ->> 'role' = 'admin', false)
      or exists (
        select 1
        from public.profiles profile
        where profile.id = auth.uid()
          and profile.account_type = 'admin'
      );
$$;

revoke all on function public.is_firstvue_admin() from public;
grant execute on function public.is_firstvue_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Block client self-escalation to admin via profiles.account_type
-- ---------------------------------------------------------------------------
create or replace function public.protect_profile_account_type()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.account_type is null or new.account_type = 'admin' then
      new.account_type := 'customer';
    elsif new.account_type not in ('customer', 'professional', 'business_owner') then
      new.account_type := 'customer';
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.account_type = 'admin' then
      new.account_type := 'admin';
      return new;
    end if;

    if new.account_type = 'admin' then
      new.account_type := old.account_type;
    end if;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_account_type on public.profiles;
create trigger protect_profile_account_type
  before insert or update on public.profiles
  for each row execute function public.protect_profile_account_type();

-- ---------------------------------------------------------------------------
-- 3. Replace broad profiles policy with scoped read/write rules
-- ---------------------------------------------------------------------------
drop policy if exists "Users manage their own profile" on public.profiles;

drop policy if exists "Users read their own profile" on public.profiles;
create policy "Users read their own profile"
  on public.profiles for select to authenticated
  using (id = auth.uid());

drop policy if exists "Users insert their own profile" on public.profiles;
create policy "Users insert their own profile"
  on public.profiles for insert to authenticated
  with check (
    id = auth.uid()
    and account_type in ('customer', 'professional', 'business_owner')
  );

drop policy if exists "Users update their own profile" on public.profiles;
create policy "Users update their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4. Recreate admin policies using is_firstvue_admin()
-- ---------------------------------------------------------------------------
drop policy if exists "FirstVue admins manage rentals" on public.rentals;
create policy "FirstVue admins manage rentals"
  on public.rentals for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins manage rental media" on public.rental_media;
create policy "FirstVue admins manage rental media"
  on public.rental_media for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins read rental media files" on storage.objects;
create policy "FirstVue admins read rental media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'rental-media'
    and public.is_firstvue_admin()
  );

drop policy if exists "FirstVue admins manage businesses" on public.businesses;
create policy "FirstVue admins manage businesses"
  on public.businesses for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins manage verification submissions" on public.business_verification_submissions;
create policy "FirstVue admins manage verification submissions"
  on public.business_verification_submissions for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins manage reviews" on public.business_reviews;
create policy "FirstVue admins manage reviews"
  on public.business_reviews for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins manage professional profiles" on public.professional_profiles;
create policy "FirstVue admins manage professional profiles"
  on public.professional_profiles for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- 5. business_memberships — was RLS-enabled with no policies
-- ---------------------------------------------------------------------------
drop policy if exists "Members read their business memberships" on public.business_memberships;
create policy "Members read their business memberships"
  on public.business_memberships for select to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Business owners read memberships on their businesses" on public.business_memberships;
create policy "Business owners read memberships on their businesses"
  on public.business_memberships for select to authenticated
  using (
    exists (
      select 1 from public.businesses business
      where business.id = business_memberships.business_id
        and business.created_by = auth.uid()
    )
  );

drop policy if exists "FirstVue admins manage business memberships" on public.business_memberships;
create policy "FirstVue admins manage business memberships"
  on public.business_memberships for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- 6. business_claims — add admin moderation
-- ---------------------------------------------------------------------------
drop policy if exists "FirstVue admins manage business claims" on public.business_claims;
create policy "FirstVue admins manage business claims"
  on public.business_claims for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- 7. Safe profile bootstrap RPC (sign-up / sign-in)
-- ---------------------------------------------------------------------------
create or replace function public.ensure_user_profile(display_name text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.profiles (id, display_name, account_type)
  values (auth.uid(), display_name, 'customer')
  on conflict (id) do update
    set display_name = coalesce(public.profiles.display_name, excluded.display_name),
        updated_at = now()
    where public.profiles.id = auth.uid();
end;
$$;

revoke all on function public.ensure_user_profile(text) from public;
grant execute on function public.ensure_user_profile(text) to authenticated;
