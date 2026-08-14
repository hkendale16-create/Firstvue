-- =============================================================================
-- FirstVue Phase 2 / Repair 1 — emergency profile RLS (FV-C01, FV-C02)
-- and re-assert non-recursive community hub policies (FV-H01).
--
-- Do NOT disable RLS. Do NOT apply to production until a backup is taken.
--
-- Problem:
--   Permissive SELECT policies on public.profiles used
--   `display_name is not null`. RLS is row-level, so any client with the
--   publishable key could select phone, birthday, latitude, longitude, and
--   field_visibility for those rows — including profiles marked private.
--   fetch_public_profile already strips fields but was optional.
--
-- Fix:
--   1) Table SELECT is own-row + admin only.
--   2) Directory / feed / search reads go through profile_public_cards,
--      a security-barrier view that exposes only non-PII columns.
--   3) Detailed stranger views use fetch_public_profile (granted to anon).
--
-- Rollback (keep RLS enabled):
--   drop view if exists public.profile_public_cards;
--   drop policy if exists "FirstVue admins read profiles" on public.profiles;
--   create policy "Public can read owner display identities" on public.profiles
--     for select to anon, authenticated using (display_name is not null);
--   create policy "Authenticated read member profile summaries" on public.profiles
--     for select to authenticated
--     using (display_name is not null or id = auth.uid());
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Tighten table SELECT
-- ---------------------------------------------------------------------------
drop policy if exists "Public can read owner display identities" on public.profiles;
drop policy if exists "Authenticated read member profile summaries" on public.profiles;

drop policy if exists "Users read their own profile" on public.profiles;
create policy "Users read their own profile"
  on public.profiles for select to authenticated
  using (id = auth.uid());

drop policy if exists "FirstVue admins read profiles" on public.profiles;
create policy "FirstVue admins read profiles"
  on public.profiles for select to authenticated
  using (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- B) Public card view — display identity only (no phone/birthday/GPS/PII)
--    security_invoker=false: view owner reads profiles bypassing table RLS,
--    then exposes only the safe column set. security_barrier limits leaky
--    predicate pushdown.
-- ---------------------------------------------------------------------------
drop view if exists public.profile_public_cards;

create view public.profile_public_cards
with (security_invoker = false, security_barrier = true) as
select
  p.id,
  p.display_name,
  p.username,
  coalesce(p.is_private, false) as is_private,
  coalesce(p.profile_visibility, 'public') as profile_visibility
from public.profiles p;

comment on view public.profile_public_cards is
  'Safe directory cards for feeds/search. No phone, birthday, coordinates, postal_code, field_visibility, or account_type.';

revoke all on public.profile_public_cards from public;
grant select on public.profile_public_cards to anon, authenticated;

-- ---------------------------------------------------------------------------
-- C) fetch_public_profile — grant to anon; never leak admin account_type
-- ---------------------------------------------------------------------------
create or replace function public.fetch_public_profile(p_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_row public.profiles%rowtype;
  v_out jsonb;
  v_account text;
  v_self boolean;
begin
  select * into v_row from public.profiles where id = p_profile_id;
  if not found then
    return null;
  end if;

  v_self := auth.uid() is not null and (
    auth.uid() = p_profile_id or public.is_firstvue_admin()
  );
  v_account := v_row.account_type;
  if v_account = 'admin' and not v_self then
    v_account := 'customer';
  end if;

  v_out := jsonb_build_object(
    'id', v_row.id,
    'display_name', v_row.display_name,
    'username', v_row.username,
    'account_type', v_account,
    'is_private', coalesce(v_row.is_private, false),
    'profile_visibility', coalesce(v_row.profile_visibility, 'public')
  );

  if public.profile_field_is_visible(p_profile_id, 'bio', 'public') then
    v_out := v_out || jsonb_build_object('bio', v_row.bio);
  end if;
  if public.profile_field_is_visible(p_profile_id, 'website', 'public') then
    v_out := v_out || jsonb_build_object('website', v_row.website);
  end if;
  if public.profile_field_is_visible(p_profile_id, 'city', 'public') then
    v_out := v_out || jsonb_build_object(
      'city', v_row.city,
      'state', v_row.state
    );
  end if;
  -- postal_code is not returned to strangers even when city is public.
  if v_self then
    v_out := v_out || jsonb_build_object('postal_code', v_row.postal_code);
  end if;
  if public.profile_field_is_visible(p_profile_id, 'phone', 'private') then
    v_out := v_out || jsonb_build_object('phone', v_row.phone);
  end if;
  if public.profile_field_is_visible(p_profile_id, 'birthday', 'private') then
    v_out := v_out || jsonb_build_object('birthday', v_row.birthday);
  end if;
  if coalesce(v_row.show_email_on_profile, false)
     and public.profile_field_is_visible(p_profile_id, 'email', 'private') then
    v_out := v_out || jsonb_build_object('show_email_on_profile', true);
  else
    v_out := v_out || jsonb_build_object('show_email_on_profile', false);
  end if;

  if v_self then
    v_out := v_out || jsonb_build_object(
      'field_visibility', coalesce(v_row.field_visibility, '{}'::jsonb)
    );
  end if;

  return v_out;
end;
$$;

revoke all on function public.fetch_public_profile(uuid) from public;
grant execute on function public.fetch_public_profile(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- D) Re-assert non-recursive hub policies (FV-H01). Helpers from 20260910
--    stay in place. Recreating policies is idempotent.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  if to_regprocedure('public.has_hub_role(uuid, uuid, boolean)') is null
     or to_regprocedure('public.is_active_hub_manager(uuid, uuid)') is null then
    raise exception
      'has_hub_role / is_active_hub_manager missing — apply 20260910 before 20260916';
  end if;

  for r in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'community_hub_roles'
  loop
    execute format(
      'drop policy if exists %I on public.community_hub_roles',
      r.policyname
    );
  end loop;
end $$;

create policy "Public read own or public hub roles"
  on public.community_hub_roles for select
  to anon, authenticated
  using (
    profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hubs h
      where h.id = community_hub_roles.hub_id
        and h.status = 'active'
        and h.visibility = 'public'
        and h.show_managers_publicly = true
        and community_hub_roles.status = 'active'
    )
  );

create policy "Managers insert hub roles"
  on public.community_hub_roles for insert
  to authenticated
  with check (
    public.is_firstvue_admin()
    or public.is_active_hub_manager(hub_id)
    or (
      profile_id = auth.uid()
      and role = 'creator'
      and exists (
        select 1 from public.community_hubs h
        where h.id = hub_id
          and h.created_by_profile_id = auth.uid()
      )
    )
  );

create policy "Managers update hub roles"
  on public.community_hub_roles for update
  to authenticated
  using (
    public.is_firstvue_admin()
    or public.is_active_hub_manager(hub_id)
    or exists (
      select 1 from public.community_hubs h
      where h.id = community_hub_roles.hub_id
        and h.created_by_profile_id = auth.uid()
    )
  )
  with check (
    public.is_firstvue_admin()
    or public.is_active_hub_manager(hub_id)
    or exists (
      select 1 from public.community_hubs h
      where h.id = community_hub_roles.hub_id
        and h.created_by_profile_id = auth.uid()
    )
  );

create policy "Managers delete hub roles"
  on public.community_hub_roles for delete
  to authenticated
  using (
    public.is_firstvue_admin()
    or public.is_active_hub_manager(hub_id)
    or exists (
      select 1 from public.community_hubs h
      where h.id = community_hub_roles.hub_id
        and h.created_by_profile_id = auth.uid()
    )
  );

drop policy if exists "Authenticated read public community hubs" on public.community_hubs;
drop policy if exists "Public read approved community hubs" on public.community_hubs;
create policy "Public read approved community hubs"
  on public.community_hubs for select
  to anon, authenticated
  using (
    (
      status = 'active'
      and visibility = 'public'
    )
    or created_by_profile_id = auth.uid()
    or leader_user_id = auth.uid()
    or public.is_firstvue_admin()
    or public.has_hub_role(id, auth.uid(), false)
  );

notify pgrst, 'reload schema';
