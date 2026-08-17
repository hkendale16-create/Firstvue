-- Entity address + distance discovery support for professional profiles,
-- plus a per-user tutorial progress marker. Safe to re-run.

alter table public.professional_profiles
  add column if not exists address_line_1 text;

alter table public.professional_profiles
  add column if not exists latitude double precision;

alter table public.professional_profiles
  add column if not exists longitude double precision;

alter table public.professional_profiles
  add column if not exists place_id text;

alter table public.professional_profiles
  add column if not exists formatted_address text;

comment on column public.professional_profiles.latitude is
  'Entities that want to appear in nearby/distance discovery should store lat/lng alongside their address.';
comment on column public.professional_profiles.longitude is
  'Entities that want to appear in nearby/distance discovery should store lat/lng alongside their address.';

create index if not exists professional_profiles_geo_idx
  on public.professional_profiles (latitude, longitude)
  where latitude is not null and longitude is not null;

alter table public.profiles
  add column if not exists tutorial_version_seen integer not null default 0;

-- ---------------------------------------------------------------------------
-- Owner-only permanent deletion for individual professional profiles.
-- Mirrors public.delete_owned_business (20260910_community_rls_recursion_
-- media_delete.sql): detaches/removes owner-authored news posts, then lets
-- ON DELETE CASCADE remove professional_media, professional_social_links,
-- professional_social_posts, and professional_catalog_items.
-- ---------------------------------------------------------------------------
create or replace function public.delete_owned_professional(p_professional_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  select profile_id into v_owner
  from public.professional_profiles
  where id = p_professional_profile_id
  for update;

  if v_owner is null then
    raise exception 'Professional profile not found'
      using errcode = 'P0002';
  end if;

  if v_owner <> auth.uid() and not public.is_firstvue_admin() then
    raise exception 'Only the owner can permanently delete this professional profile'
      using errcode = '42501';
  end if;

  -- Keep user-authored posts that mention the professional; detach the entity.
  update public.community_news_posts
  set professional_profile_id = null
  where professional_profile_id = p_professional_profile_id
    and author_id <> v_owner;

  delete from public.community_news_posts
  where professional_profile_id = p_professional_profile_id
    and author_id = v_owner;

  -- professional_media / professional_social_links / professional_social_posts
  -- / professional_catalog_items all reference this row with ON DELETE CASCADE.
  delete from public.professional_profiles where id = p_professional_profile_id;
end;
$$;

comment on function public.delete_owned_professional(uuid) is
  'Owner-only permanent professional-profile deletion. Removes entity-owned media/catalogs/posts via cascade.';

revoke all on function public.delete_owned_professional(uuid) from public;
grant execute on function public.delete_owned_professional(uuid) to authenticated;
