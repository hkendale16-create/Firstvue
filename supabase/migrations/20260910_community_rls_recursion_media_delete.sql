-- =============================================================================
-- FirstVue Phase 1 — break community_hub_roles RLS recursion, atomic avatar
-- replace, owner-only entity deletion.
--
-- Root cause of 42P17:
--   community_hubs SELECT exists(community_hub_roles)
--   community_hub_roles FOR ALL exists(community_hubs) AND exists(community_hub_roles)
-- Postgres evaluates all permissive policies; the self-select on hub_roles
-- recurses even when another SELECT policy is using(true).
--
-- Fix: SECURITY DEFINER helpers that read hub_roles with RLS bypassed, then
-- rewrite policies to call those helpers instead of querying hub_roles.
--
-- Safety of SECURITY DEFINER helpers:
--   * Owner is the migration role (postgres / supabase_admin).
--   * search_path is locked to public.
--   * Return type is boolean only — no role rows or PII leak.
--   * EXECUTE granted to anon/authenticated for has_hub_role (needed so
--     SELECT on community_hubs can authorize private-hub members).
--   * is_active_hub_manager is granted to authenticated only (write path).
--   * Helpers never disable RLS on the tables themselves.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Non-recursive authorization helpers
-- ---------------------------------------------------------------------------
create or replace function public.has_hub_role(
  p_hub_id uuid,
  p_profile_id uuid default auth.uid(),
  p_require_active boolean default true
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_profile_id is not null
    and exists (
      select 1
      from public.community_hub_roles r
      where r.hub_id = p_hub_id
        and r.profile_id = p_profile_id
        and (
          not p_require_active
          or r.status = 'active'
        )
    ),
    false
  );
$$;

comment on function public.has_hub_role(uuid, uuid, boolean) is
  'Non-recursive hub membership check. SECURITY DEFINER bypasses community_hub_roles RLS to avoid 42P17. Returns boolean only.';

create or replace function public.is_active_hub_manager(
  p_hub_id uuid,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_profile_id is not null
    and exists (
      select 1
      from public.community_hub_roles r
      where r.hub_id = p_hub_id
        and r.profile_id = p_profile_id
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    ),
    false
  );
$$;

comment on function public.is_active_hub_manager(uuid, uuid) is
  'Non-recursive active manager check. SECURITY DEFINER bypasses community_hub_roles RLS. Returns boolean only.';

revoke all on function public.has_hub_role(uuid, uuid, boolean) from public;
grant execute on function public.has_hub_role(uuid, uuid, boolean) to anon, authenticated;

revoke all on function public.is_active_hub_manager(uuid, uuid) from public;
grant execute on function public.is_active_hub_manager(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- B) Rewrite hub_roles policies — drop every existing policy, then recreate
--    without self-select on community_hub_roles.
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
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

-- SELECT: own rows, admins, or public manager rows when the hub opts in.
-- Does not query community_hub_roles.
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

-- INSERT/UPDATE/DELETE: admin, hub created_by, or SECURITY DEFINER manager check.
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

-- ---------------------------------------------------------------------------
-- C) Rewrite hub SELECT to use helper (no direct hub_roles subquery)
-- ---------------------------------------------------------------------------
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

drop policy if exists "Hub leaders update community hubs" on public.community_hubs;
create policy "Hub leaders update community hubs"
  on public.community_hubs for update
  to authenticated
  using (
    public.is_firstvue_admin()
    or created_by_profile_id = auth.uid()
    or public.is_active_hub_manager(id)
  )
  with check (
    public.is_firstvue_admin()
    or created_by_profile_id = auth.uid()
    or public.is_active_hub_manager(id)
  );

-- ---------------------------------------------------------------------------
-- D) Atomic avatar/cover replace: UPDATE in place, insert only if missing
-- ---------------------------------------------------------------------------
create or replace function public.replace_role_media(
  p_table text,
  p_owner_column text,
  p_owner_id uuid,
  p_storage_path text,
  p_storage_provider text,
  p_media_type text,
  p_media_role text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_allowed boolean := false;
  v_old_path text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_media_role not in ('avatar', 'cover') then
    raise exception 'media_role must be avatar or cover';
  end if;

  if p_table = 'profile_media' and p_owner_column = 'profile_id' then
    v_allowed := coalesce(p_owner_id = auth.uid(), false);
  elsif p_table = 'business_media' and p_owner_column = 'business_id' then
    v_allowed := exists (
      select 1 from public.businesses b
      where b.id = p_owner_id and b.created_by = auth.uid()
    ) or exists (
      select 1 from public.business_memberships bm
      where bm.business_id = p_owner_id
        and bm.profile_id = auth.uid()
        and bm.role in ('owner', 'manager')
    );
  elsif p_table = 'professional_media'
    and p_owner_column = 'professional_profile_id' then
    v_allowed := exists (
      select 1 from public.professional_profiles p
      where p.id = p_owner_id and p.profile_id = auth.uid()
    );
  else
    raise exception 'Unsupported media table';
  end if;

  if not coalesce(v_allowed, false) and not public.is_firstvue_admin() then
    raise exception 'Not authorized to replace this media';
  end if;

  execute format(
    'select id, storage_path from public.%I where %I = $1 and media_role = $2 order by created_at desc limit 1',
    p_table,
    p_owner_column
  )
  into v_id, v_old_path
  using p_owner_id, p_media_role;

  if v_id is not null then
    -- UPDATE in place so business_media_one_avatar_idx is never violated.
    execute format(
      'update public.%I
         set storage_path = $2,
             storage_provider = $3,
             media_type = $4
       where id = $1',
      p_table
    )
    using v_id, p_storage_path, p_storage_provider, p_media_type;

    execute format(
      'delete from public.%I where %I = $1 and media_role = $2 and id <> $3',
      p_table,
      p_owner_column
    )
    using p_owner_id, p_media_role, v_id;
  else
    execute format(
      'insert into public.%I (%I, storage_path, storage_provider, media_type, sort_order, media_role)
       values ($1, $2, $3, $4, 0, $5)
       returning id',
      p_table,
      p_owner_column
    )
    into v_id
    using p_owner_id, p_storage_path, p_storage_provider, p_media_type, p_media_role;
  end if;

  return v_id;
end;
$$;

revoke all on function public.replace_role_media(text, text, uuid, text, text, text, text) from public;
grant execute on function public.replace_role_media(text, text, uuid, text, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- E) Owner-only permanent business deletion
--     Reviews are anonymized (not cascade-deleted). Do not execute against
--     live production entities during development/testing.
-- ---------------------------------------------------------------------------
do $$
begin
  alter table public.business_reviews
    drop constraint if exists business_reviews_business_id_fkey;
exception
  when undefined_object then null;
end $$;

alter table public.business_reviews
  alter column business_id drop not null;

alter table public.business_reviews
  add column if not exists former_business_name text;

do $$
begin
  alter table public.business_reviews
    add constraint business_reviews_business_id_fkey
    foreign key (business_id) references public.businesses(id) on delete set null;
exception
  when duplicate_object then null;
end $$;

create or replace function public.delete_owned_business(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  select created_by, name into v_owner, v_name
  from public.businesses
  where id = p_business_id
  for update;

  if v_owner is null then
    raise exception 'Business not found'
      using errcode = 'P0002';
  end if;

  if v_owner <> auth.uid() and not public.is_firstvue_admin() then
    raise exception 'Only the owner can permanently delete this business'
      using errcode = '42501';
  end if;

  -- Keep user-authored posts that mention the business; detach the entity.
  update public.community_news_posts
  set business_id = null
  where business_id = p_business_id
    and author_id <> v_owner;

  delete from public.community_news_posts
  where business_id = p_business_id
    and author_id = v_owner;

  -- Anonymize reviews for historical integrity instead of deleting UGC.
  update public.business_reviews
  set former_business_name = coalesce(former_business_name, v_name),
      business_id = null
  where business_id = p_business_id;

  delete from public.business_media where business_id = p_business_id;
  delete from public.business_follows where business_id = p_business_id;
  delete from public.business_memberships where business_id = p_business_id;

  begin
    delete from public.business_promotions where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.business_menu_items where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.business_specials where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.business_services where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.business_social_links where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.business_locations where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.entity_customers where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  begin
    delete from public.entity_inventory_items where business_id = p_business_id;
  exception
    when undefined_table then null;
  end;

  delete from public.businesses where id = p_business_id;
end;
$$;

comment on function public.delete_owned_business(uuid) is
  'Owner-only permanent business deletion. Removes entity-owned media/catalogs/posts. Anonymizes reviews. Managers cannot call this.';

revoke all on function public.delete_owned_business(uuid) from public;
grant execute on function public.delete_owned_business(uuid) to authenticated;
