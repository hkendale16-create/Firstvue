-- =============================================================================
-- FirstVue Phase 1 — media replace hardening, community image persistence,
-- community findability helpers, privacy field visibility, entity details.
--
-- READ-ONLY diagnosis (live project sdssshegqdwobjelxzkp, 2026-08-12):
--
-- 1) Entity profile photo bug
--    Root cause: unique partial indexes (profile/business/professional_media
--    one avatar/cover per owner) + Flutter delete-then-insert fallback races;
--    replace_role_media failed open when auth.uid() is null because
--    `v_allowed := p_owner_id = auth.uid()` yields NULL and the IF check skips.
--    Affected: profile_media, business_media, professional_media;
--    constraints: profile_media_one_avatar_per_profile / _cover_,
--    business_media_one_avatar_idx / _cover_,
--    professional_media_one_avatar_idx / _cover_.
--    Flutter: profile_media_service / business_media_service /
--    professional_media_service (catch-all RPC fallback).
--
-- 2) Group / entity image persistence
--    Root cause: CommunityMediaService stores expiring signed URLs in
--    communities.image_url / community_hubs.image_url (TTL ~3600s).
--    Fix: persist storage_path (+ provider); resign on read.
--
-- 3) Approved communities not found
--    Root cause: approval writes community_hubs (status=active), but search
--    only queries communities (groups); nearby hubs over-filter by location.
--    Flutter findability fix is primary; this migration adds active-status
--    clarity only.
--
-- 4) Privacy / entity details (Phase 2 foundation)
--    profiles already has is_private + profile_visibility. Add
--    field_visibility jsonb + contact fields. Add entity_details jsonb on
--    businesses / professional_profiles / rentals / community_hubs for
--    type-specific attributes without duplicating tables.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Harden atomic replace_role_media (auth.uid() null fail-open)
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
    'delete from public.%I where %I = $1 and media_role = $2',
    p_table,
    p_owner_column
  ) using p_owner_id, p_media_role;

  execute format(
    'insert into public.%I (%I, storage_path, storage_provider, media_type, sort_order, media_role)
     values ($1, $2, $3, $4, 0, $5)
     returning id',
    p_table,
    p_owner_column
  )
  into v_id
  using p_owner_id, p_storage_path, p_storage_provider, p_media_type, p_media_role;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- B) Deduplicate any existing multi-avatar / multi-cover rows (keep newest)
-- ---------------------------------------------------------------------------
with ranked as (
  select id,
    row_number() over (
      partition by profile_id, media_role order by created_at desc, id desc
    ) as rn
  from public.profile_media
  where media_role in ('avatar', 'cover')
)
delete from public.profile_media pm
using ranked r
where pm.id = r.id and r.rn > 1;

with ranked as (
  select id,
    row_number() over (
      partition by business_id, media_role order by created_at desc, id desc
    ) as rn
  from public.business_media
  where media_role in ('avatar', 'cover')
)
delete from public.business_media bm
using ranked r
where bm.id = r.id and r.rn > 1;

with ranked as (
  select id,
    row_number() over (
      partition by professional_profile_id, media_role
      order by created_at desc, id desc
    ) as rn
  from public.professional_media
  where media_role in ('avatar', 'cover')
)
delete from public.professional_media prm
using ranked r
where prm.id = r.id and r.rn > 1;

-- ---------------------------------------------------------------------------
-- C) Community / group image persistence (storage path, not signed URL)
-- ---------------------------------------------------------------------------
alter table public.communities
  add column if not exists image_storage_path text,
  add column if not exists image_storage_provider text default 'supabase';

alter table public.community_hubs
  add column if not exists image_storage_path text,
  add column if not exists image_storage_provider text default 'supabase',
  add column if not exists cover_storage_path text,
  add column if not exists cover_storage_provider text default 'supabase';

-- Best-effort backfill: extract path from Supabase signed / object URLs.
update public.communities
set image_storage_path = coalesce(
  image_storage_path,
  nullif(
    substring(
      image_url
      from '/storage/v1/object/(?:sign|public)/profile-media/([^?]+)'
    ),
    ''
  )
)
where image_url is not null
  and image_storage_path is null
  and image_url like '%/storage/v1/object/%/profile-media/%';

update public.community_hubs
set image_storage_path = coalesce(
  image_storage_path,
  nullif(
    substring(
      image_url
      from '/storage/v1/object/(?:sign|public)/profile-media/([^?]+)'
    ),
    ''
  )
)
where image_url is not null
  and image_storage_path is null
  and image_url like '%/storage/v1/object/%/profile-media/%';

update public.community_hubs
set cover_storage_path = coalesce(
  cover_storage_path,
  nullif(
    substring(
      cover_url
      from '/storage/v1/object/(?:sign|public)/profile-media/([^?]+)'
    ),
    ''
  )
)
where cover_url is not null
  and cover_storage_path is null
  and cover_url like '%/storage/v1/object/%/profile-media/%';

-- Paths mistakenly stored in image_url (no scheme) become storage paths.
update public.communities
set image_storage_path = coalesce(image_storage_path, image_url)
where image_storage_path is null
  and image_url is not null
  and image_url not like 'http%'
  and position('/' in image_url) > 0;

update public.community_hubs
set image_storage_path = coalesce(image_storage_path, image_url)
where image_storage_path is null
  and image_url is not null
  and image_url not like 'http%'
  and position('/' in image_url) > 0;

-- ---------------------------------------------------------------------------
-- D) Business media manage RLS — owners + managers (align with replace RPC)
-- ---------------------------------------------------------------------------
drop policy if exists "Owners manage business media" on public.business_media;
drop policy if exists "Owners read their business media records" on public.business_media;
drop policy if exists "Business managers manage business media" on public.business_media;

create policy "Business managers manage business media"
  on public.business_media for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and b.created_by = auth.uid()
    )
    or exists (
      select 1 from public.business_memberships bm
      where bm.business_id = business_id
        and bm.profile_id = auth.uid()
        and bm.role in ('owner', 'manager')
    )
    or public.is_firstvue_admin()
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_id and b.created_by = auth.uid()
    )
    or exists (
      select 1 from public.business_memberships bm
      where bm.business_id = business_id
        and bm.profile_id = auth.uid()
        and bm.role in ('owner', 'manager')
    )
    or public.is_firstvue_admin()
  );

-- ---------------------------------------------------------------------------
-- E) Profile avatar lookup RPC (profiles.avatar_url does not exist)
-- ---------------------------------------------------------------------------
create or replace function public.fetch_profile_avatars(p_profile_ids uuid[])
returns table (
  profile_id uuid,
  storage_path text,
  storage_provider text
)
language sql
stable
security definer
set search_path = public
as $$
  select distinct on (pm.profile_id)
    pm.profile_id,
    pm.storage_path,
    pm.storage_provider
  from public.profile_media pm
  where pm.profile_id = any (p_profile_ids)
    and pm.media_role = 'avatar'
  order by pm.profile_id, pm.created_at desc, pm.id desc;
$$;

revoke all on function public.fetch_profile_avatars(uuid[]) from public;
grant execute on function public.fetch_profile_avatars(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- F) Privacy field visibility + contact fields on profiles
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists phone text,
  add column if not exists birthday date,
  add column if not exists show_email_on_profile boolean not null default false,
  add column if not exists field_visibility jsonb not null default '{}'::jsonb;

comment on column public.profiles.field_visibility is
  'Map of field -> public|followers|private. Enforced by fetch_public_profile.';

create or replace function public.viewer_follows_profile(p_owner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and exists (
      select 1 from public.profile_follows pf
      where pf.following_id = p_owner_id
        and pf.follower_id = auth.uid()
    );
$$;

revoke all on function public.viewer_follows_profile(uuid) from public;
grant execute on function public.viewer_follows_profile(uuid) to authenticated;

create or replace function public.profile_field_is_visible(
  p_owner_id uuid,
  p_field text,
  p_default text default 'public'
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_vis text;
  v_profile public.profiles%rowtype;
  v_profile_vis text;
begin
  if auth.uid() is not null and (
    auth.uid() = p_owner_id or public.is_firstvue_admin()
  ) then
    return true;
  end if;

  select * into v_profile from public.profiles where id = p_owner_id;
  if not found then
    return false;
  end if;

  v_profile_vis := case
    when coalesce(v_profile.is_private, false) then 'private'
    else coalesce(v_profile.profile_visibility, 'public')
  end;

  if v_profile_vis = 'private' and not public.viewer_follows_profile(p_owner_id) then
    return false;
  end if;

  if v_profile_vis = 'followers' and not public.viewer_follows_profile(p_owner_id) then
    return false;
  end if;

  v_vis := coalesce(v_profile.field_visibility ->> p_field, p_default);

  if v_vis = 'public' then
    return true;
  end if;
  if v_vis = 'private' then
    return false;
  end if;
  if v_vis = 'followers' then
    return public.viewer_follows_profile(p_owner_id);
  end if;

  return true;
end;
$$;

revoke all on function public.profile_field_is_visible(uuid, text, text) from public;
grant execute on function public.profile_field_is_visible(uuid, text, text) to authenticated;

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
begin
  select * into v_row from public.profiles where id = p_profile_id;
  if not found then
    return null;
  end if;

  v_out := jsonb_build_object(
    'id', v_row.id,
    'display_name', v_row.display_name,
    'username', v_row.username,
    'account_type', v_row.account_type,
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
    v_out := v_out || jsonb_build_object('city', v_row.city, 'state', v_row.state, 'postal_code', v_row.postal_code);
  end if;
  if public.profile_field_is_visible(p_profile_id, 'phone', 'private') then
    v_out := v_out || jsonb_build_object('phone', v_row.phone);
  end if;
  if public.profile_field_is_visible(p_profile_id, 'birthday', 'private') then
    v_out := v_out || jsonb_build_object('birthday', v_row.birthday);
  end if;
  if coalesce(v_row.show_email_on_profile, false)
     and public.profile_field_is_visible(p_profile_id, 'email', 'private') then
    -- Email lives on auth.users; only expose flag for owners to sync client-side.
    v_out := v_out || jsonb_build_object('show_email_on_profile', true);
  else
    v_out := v_out || jsonb_build_object('show_email_on_profile', false);
  end if;

  v_out := v_out || jsonb_build_object(
    'field_visibility', coalesce(v_row.field_visibility, '{}'::jsonb)
  );

  return v_out;
end;
$$;

revoke all on function public.fetch_public_profile(uuid) from public;
grant execute on function public.fetch_public_profile(uuid) to authenticated;

-- Owners update privacy settings on their own row (existing profiles RLS).
-- Keep field_visibility values constrained via trigger.
create or replace function public.validate_profile_field_visibility()
returns trigger
language plpgsql
as $$
declare
  k text;
  v text;
begin
  if new.field_visibility is null then
    new.field_visibility := '{}'::jsonb;
  end if;
  for k, v in select * from jsonb_each_text(new.field_visibility)
  loop
    if v not in ('public', 'followers', 'private') then
      raise exception 'Invalid visibility "%" for field %', v, k;
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists profiles_validate_field_visibility on public.profiles;
create trigger profiles_validate_field_visibility
  before insert or update of field_visibility on public.profiles
  for each row execute function public.validate_profile_field_visibility();

-- ---------------------------------------------------------------------------
-- G) Entity-specific details (jsonb) — reuse tables, no duplicates
-- ---------------------------------------------------------------------------
alter table public.businesses
  add column if not exists entity_details jsonb not null default '{}'::jsonb,
  add column if not exists subcategory text,
  add column if not exists phone text,
  add column if not exists website text,
  add column if not exists price_range text,
  add column if not exists service_area text;

alter table public.professional_profiles
  add column if not exists entity_details jsonb not null default '{}'::jsonb,
  add column if not exists title text,
  add column if not exists company text,
  add column if not exists specialty text,
  add column if not exists experience_years integer,
  add column if not exists service_area text;

alter table public.rentals
  add column if not exists entity_details jsonb not null default '{}'::jsonb,
  add column if not exists property_type text,
  add column if not exists bedrooms numeric,
  add column if not exists bathrooms numeric,
  add column if not exists square_footage integer,
  add column if not exists deposit_cents integer,
  add column if not exists lease_length text,
  add column if not exists pet_policy text;

alter table public.community_hubs
  add column if not exists entity_details jsonb not null default '{}'::jsonb;

alter table public.communities
  add column if not exists entity_details jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- H) Portfolio album owner types: allow community / group / rental later-safe
--    Keep check compatible; extend only if constraint exists.
-- ---------------------------------------------------------------------------
do $$
begin
  alter table public.media_albums
    drop constraint if exists media_albums_owner_type_check;
  alter table public.media_albums
    add constraint media_albums_owner_type_check
    check (owner_type in (
      'user', 'business', 'professional', 'rental', 'group', 'community'
    ));
exception when others then
  null;
end $$;

create or replace function public.owns_media_album_owner(
  p_owner_type text,
  p_owner_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_owner_type
    when 'user' then p_owner_id = auth.uid()
    when 'business' then (
      exists (
        select 1 from public.businesses b
        where b.id = p_owner_id and b.created_by = auth.uid()
      )
      or exists (
        select 1 from public.business_memberships bm
        where bm.business_id = p_owner_id
          and bm.profile_id = auth.uid()
          and bm.role in ('owner', 'manager')
      )
    )
    when 'professional' then exists (
      select 1 from public.professional_profiles p
      where p.id = p_owner_id and p.profile_id = auth.uid()
    )
    when 'rental' then exists (
      select 1 from public.rentals r
      where r.id = p_owner_id and r.owner_id = auth.uid()
    )
    when 'group' then exists (
      select 1 from public.communities c
      where c.id = p_owner_id and c.creator_id = auth.uid()
    )
    when 'community' then (
      exists (
        select 1 from public.community_hubs h
        where h.id = p_owner_id
          and (
            h.created_by_profile_id = auth.uid()
            or h.leader_user_id = auth.uid()
          )
      )
      or exists (
        select 1 from public.community_hub_roles r
        where r.hub_id = p_owner_id
          and r.profile_id = auth.uid()
          and r.status = 'active'
          and r.role in ('creator', 'lead_leader', 'leader', 'admin')
      )
    )
    else false
  end;
$$;
