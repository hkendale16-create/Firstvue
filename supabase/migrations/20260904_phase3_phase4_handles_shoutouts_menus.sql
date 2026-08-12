-- =============================================================================
-- FirstVue Phase 3–4: entity handles, post backgrounds, shoutout engagement,
-- menu images/availability, smart address fields, shoutout group targets.
-- Non-destructive; extends existing tables/RLS. Does not disable RLS.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Universal @handles registry (users already use profiles.username)
-- ---------------------------------------------------------------------------
create table if not exists public.entity_handles (
  handle citext primary key,
  entity_type text not null
    check (entity_type in (
      'user', 'business', 'professional', 'rental', 'group', 'community'
    )),
  entity_id uuid not null,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (entity_type, entity_id)
);

create index if not exists entity_handles_entity_idx
  on public.entity_handles (entity_type, entity_id);

alter table public.entity_handles enable row level security;

drop policy if exists "Authenticated read entity handles" on public.entity_handles;
create policy "Authenticated read entity handles"
  on public.entity_handles for select to authenticated
  using (true);

drop policy if exists "Owners manage entity handles" on public.entity_handles;
create policy "Owners manage entity handles"
  on public.entity_handles for all to authenticated
  using (
    created_by = auth.uid()
    or public.is_firstvue_admin()
    or (
      entity_type = 'user' and entity_id = auth.uid()
    )
    or (
      entity_type = 'business' and exists (
        select 1 from public.businesses b
        where b.id = entity_id and b.created_by = auth.uid()
      )
    )
    or (
      entity_type = 'professional' and exists (
        select 1 from public.professional_profiles p
        where p.id = entity_id and p.profile_id = auth.uid()
      )
    )
    or (
      entity_type = 'rental' and exists (
        select 1 from public.rentals r
        where r.id = entity_id and r.owner_id = auth.uid()
      )
    )
    or (
      entity_type = 'group' and exists (
        select 1 from public.communities c
        where c.id = entity_id and c.creator_id = auth.uid()
      )
    )
    or (
      entity_type = 'community' and exists (
        select 1 from public.community_hubs h
        where h.id = entity_id
          and (h.created_by_profile_id = auth.uid() or h.leader_user_id = auth.uid())
      )
    )
  )
  with check (
    created_by = auth.uid()
    or public.is_firstvue_admin()
    or (entity_type = 'user' and entity_id = auth.uid())
  );

-- Keep user handles mirrored from profiles.username
insert into public.entity_handles (handle, entity_type, entity_id, created_by)
select lower(username::text), 'user', id, id
from public.profiles
where username is not null
  and length(trim(username::text)) >= 3
on conflict (handle) do nothing;

create or replace function public.normalize_entity_handle(candidate text)
returns text
language sql
immutable
as $$
  select nullif(
    lower(regexp_replace(trim(both from coalesce(candidate, '')), '^@+', '')),
    ''
  );
$$;

create or replace function public.is_entity_handle_available(
  candidate text,
  p_entity_type text default null,
  p_entity_id uuid default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_handle text;
begin
  v_handle := public.normalize_entity_handle(candidate);
  if v_handle is null or char_length(v_handle) < 3 or char_length(v_handle) > 30 then
    return false;
  end if;
  if v_handle !~ '^[a-z0-9_]+$' then
    return false;
  end if;

  -- Conflict with profiles.username (unless claiming own user handle)
  if exists (
    select 1 from public.profiles p
    where lower(p.username::text) = v_handle
      and not (
        p_entity_type = 'user' and p.id = p_entity_id
      )
  ) then
    return false;
  end if;

  if exists (
    select 1 from public.entity_handles h
    where h.handle = v_handle
      and not (
        p_entity_type is not null
        and p_entity_id is not null
        and h.entity_type = p_entity_type
        and h.entity_id = p_entity_id
      )
  ) then
    return false;
  end if;

  return true;
end;
$$;

revoke all on function public.is_entity_handle_available(text, text, uuid) from public;
grant execute on function public.is_entity_handle_available(text, text, uuid) to authenticated;

create or replace function public.set_entity_handle(
  p_entity_type text,
  p_entity_id uuid,
  candidate text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_handle text;
  v_allowed boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_handle := public.normalize_entity_handle(candidate);
  if v_handle is null or char_length(v_handle) < 3 or char_length(v_handle) > 30
     or v_handle !~ '^[a-z0-9_]+$' then
    raise exception 'Invalid handle';
  end if;

  if not public.is_entity_handle_available(v_handle, p_entity_type, p_entity_id) then
    raise exception 'Handle is not available';
  end if;

  v_allowed := case p_entity_type
    when 'user' then p_entity_id = auth.uid()
    when 'business' then exists (
      select 1 from public.businesses b
      where b.id = p_entity_id and b.created_by = auth.uid()
    )
    when 'professional' then exists (
      select 1 from public.professional_profiles p
      where p.id = p_entity_id and p.profile_id = auth.uid()
    )
    when 'rental' then exists (
      select 1 from public.rentals r
      where r.id = p_entity_id and r.owner_id = auth.uid()
    )
    when 'group' then exists (
      select 1 from public.communities c
      where c.id = p_entity_id and c.creator_id = auth.uid()
    )
    when 'community' then exists (
      select 1 from public.community_hubs h
      where h.id = p_entity_id
        and (h.created_by_profile_id = auth.uid() or h.leader_user_id = auth.uid())
    )
    else false
  end;

  if not coalesce(v_allowed, false) and not public.is_firstvue_admin() then
    raise exception 'Not authorized to set this handle';
  end if;

  insert into public.entity_handles (handle, entity_type, entity_id, created_by, updated_at)
  values (v_handle, p_entity_type, p_entity_id, auth.uid(), now())
  on conflict (entity_type, entity_id) do update
    set handle = excluded.handle,
        updated_at = now();

  if p_entity_type = 'user' then
    update public.profiles
    set username = v_handle, updated_at = now()
    where id = p_entity_id;
  end if;

  return v_handle;
end;
$$;

revoke all on function public.set_entity_handle(text, uuid, text) from public;
grant execute on function public.set_entity_handle(text, uuid, text) to authenticated;

create or replace function public.lookup_entity_handle(candidate text)
returns table (
  handle text,
  entity_type text,
  entity_id uuid
)
language sql
stable
security definer
set search_path = public
as $$
  with normalized as (
    select public.normalize_entity_handle(candidate) as h
  )
  select eh.handle::text, eh.entity_type, eh.entity_id
  from public.entity_handles eh, normalized n
  where eh.handle = n.h
  union all
  select lower(p.username::text), 'user'::text, p.id
  from public.profiles p, normalized n
  where lower(p.username::text) = n.h
    and not exists (
      select 1 from public.entity_handles eh
      where eh.handle = n.h
    )
  limit 1;
$$;

revoke all on function public.lookup_entity_handle(text) from public;
grant execute on function public.lookup_entity_handle(text) to authenticated;

-- Suggest handles for @ autocomplete (followed first)
create or replace function public.suggest_entity_handles(
  prefix text,
  lim integer default 12
)
returns table (
  handle text,
  display_name text,
  entity_type text,
  entity_id uuid,
  priority integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_prefix text;
begin
  v_prefix := coalesce(public.normalize_entity_handle(prefix), '');
  if char_length(v_prefix) < 1 then
    return;
  end if;

  return query
  with candidates as (
    select
      eh.handle::text as handle,
      coalesce(
        case eh.entity_type
          when 'user' then (select p.display_name from public.profiles p where p.id = eh.entity_id)
          when 'business' then (select b.name from public.businesses b where b.id = eh.entity_id)
          when 'professional' then (select pr.display_name from public.professional_profiles pr where pr.id = eh.entity_id)
          when 'group' then (select c.name from public.communities c where c.id = eh.entity_id)
          when 'community' then (select h.name from public.community_hubs h where h.id = eh.entity_id)
          when 'rental' then (select r.title from public.rentals r where r.id = eh.entity_id)
        end,
        eh.handle::text
      ) as display_name,
      eh.entity_type,
      eh.entity_id,
      case
        when eh.entity_type = 'user' and exists (
          select 1 from public.profile_follows pf
          where pf.follower_id = auth.uid() and pf.following_id = eh.entity_id
        ) then 0
        when eh.entity_type = 'user' and exists (
          select 1 from public.profile_follows pf
          where pf.following_id = auth.uid() and pf.follower_id = eh.entity_id
        ) then 1
        else 2
      end as priority
    from public.entity_handles eh
    where eh.handle::text like v_prefix || '%'
  )
  select c.handle, c.display_name, c.entity_type, c.entity_id, c.priority
  from candidates c
  order by c.priority, c.handle
  limit greatest(1, least(coalesce(lim, 12), 30));
end;
$$;

revoke all on function public.suggest_entity_handles(text, integer) from public;
grant execute on function public.suggest_entity_handles(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Post background colors for composer
-- ---------------------------------------------------------------------------
alter table public.community_news_posts
  add column if not exists background_color text;

alter table public.community_news_posts
  drop constraint if exists community_news_posts_background_color_check;

alter table public.community_news_posts
  add constraint community_news_posts_background_color_check
  check (
    background_color is null
    or background_color in (
      'none', 'bronze', 'teal', 'coral', 'navy', 'forest', 'sunset', 'midnight'
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Shoutouts: ensure table + extend targets + engagement
-- (Base table also defined in 20260828_shoutouts.sql)
-- ---------------------------------------------------------------------------
create table if not exists public.shoutouts (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null,
  target_id uuid not null,
  message text not null,
  visibility text not null default 'public',
  status text not null default 'approved',
  created_at timestamptz not null default now()
);

alter table public.shoutouts
  drop constraint if exists shoutouts_target_type_check;

alter table public.shoutouts
  add constraint shoutouts_target_type_check
  check (target_type in (
    'profile', 'business', 'professional', 'event', 'community', 'group'
  ));

alter table public.shoutouts
  add column if not exists spark_count integer not null default 0,
  add column if not exists media_storage_path text,
  add column if not exists media_storage_provider text default 'supabase';

create table if not exists public.shoutout_sparks (
  shoutout_id uuid not null references public.shoutouts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (shoutout_id, user_id)
);

alter table public.shoutout_sparks enable row level security;

drop policy if exists "Authenticated read shoutout sparks" on public.shoutout_sparks;
create policy "Authenticated read shoutout sparks"
  on public.shoutout_sparks for select to authenticated using (true);

drop policy if exists "Users manage own shoutout sparks" on public.shoutout_sparks;
create policy "Users manage own shoutout sparks"
  on public.shoutout_sparks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create or replace function public.toggle_shoutout_spark(p_shoutout_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_exists boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select exists (
    select 1 from public.shoutout_sparks
    where shoutout_id = p_shoutout_id and user_id = auth.uid()
  ) into v_exists;

  if v_exists then
    delete from public.shoutout_sparks
    where shoutout_id = p_shoutout_id and user_id = auth.uid();
    update public.shoutouts
    set spark_count = greatest(0, spark_count - 1)
    where id = p_shoutout_id;
    return false;
  end if;

  insert into public.shoutout_sparks (shoutout_id, user_id)
  values (p_shoutout_id, auth.uid())
  on conflict do nothing;
  update public.shoutouts
  set spark_count = spark_count + 1
  where id = p_shoutout_id;
  return true;
end;
$$;

revoke all on function public.toggle_shoutout_spark(uuid) from public;
grant execute on function public.toggle_shoutout_spark(uuid) to authenticated;

-- Top 10 by engagement + recency (last 14 days)
create or replace function public.fetch_top_shoutouts(
  p_target_type text default null,
  p_limit integer default 10
)
returns setof public.shoutouts
language sql
stable
security definer
set search_path = public
as $$
  select s.*
  from public.shoutouts s
  where s.status = 'approved'
    and s.created_at > now() - interval '14 days'
    and (p_target_type is null or s.target_type = p_target_type)
  order by
    (coalesce(s.spark_count, 0) * 3
      + greatest(0, 20 - extract(epoch from (now() - s.created_at)) / 86400.0)
    ) desc,
    s.created_at desc
  limit greatest(1, least(coalesce(p_limit, 10), 25));
$$;

revoke all on function public.fetch_top_shoutouts(text, integer) from public;
grant execute on function public.fetch_top_shoutouts(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Menu: images, availability, category index
-- ---------------------------------------------------------------------------
alter table public.business_menu_items
  add column if not exists image_storage_path text,
  add column if not exists image_storage_provider text default 'supabase',
  add column if not exists is_available boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists business_menu_items_category_idx
  on public.business_menu_items (business_id, category, sort_order);

-- ---------------------------------------------------------------------------
-- 5) Smart address fields on business_locations (+ optional profile unit)
-- ---------------------------------------------------------------------------
alter table public.business_locations
  add column if not exists address_line_2 text,
  add column if not exists country_code text not null default 'US',
  add column if not exists formatted_address text,
  add column if not exists place_id text;

alter table public.profiles
  add column if not exists address_line_1 text,
  add column if not exists address_line_2 text,
  add column if not exists country_code text default 'US',
  add column if not exists formatted_address text,
  add column if not exists place_id text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

-- ---------------------------------------------------------------------------
-- 6) Search/discovery helper indexes for new fields
-- ---------------------------------------------------------------------------
create index if not exists businesses_entity_details_gin
  on public.businesses using gin (entity_details jsonb_path_ops);

create index if not exists professional_profiles_entity_details_gin
  on public.professional_profiles using gin (entity_details jsonb_path_ops);

create index if not exists rentals_property_type_idx
  on public.rentals (property_type)
  where property_type is not null;
