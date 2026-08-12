-- =============================================================================
-- FirstVue — Portfolio albums, atomic avatar replacement, post identity,
-- Approval Center hardening, and profile affiliation RPCs.
-- Non-destructive; extends existing media + community approval architecture.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Post identity: explicit author profile type (personal / business / etc.)
-- ---------------------------------------------------------------------------
alter table public.community_news_posts
  add column if not exists author_profile_type text
    check (author_profile_type in (
      'user', 'business', 'professional', 'community', 'event'
    ));

alter table public.community_news_posts
  add column if not exists author_profile_id uuid;

create index if not exists community_news_posts_author_profile_idx
  on public.community_news_posts (author_profile_type, author_profile_id)
  where author_profile_id is not null;

-- Backfill from existing foreign keys.
update public.community_news_posts
set author_profile_type = case
  when business_id is not null then 'business'
  when professional_profile_id is not null then 'professional'
  when event_id is not null then 'event'
  when community_id is not null then 'community'
  else 'user'
end
where author_profile_type is null;

update public.community_news_posts
set author_profile_id = coalesce(
  business_id,
  professional_profile_id,
  event_id,
  community_id
)
where author_profile_id is null
  and author_profile_type is distinct from 'user';

-- ---------------------------------------------------------------------------
-- 2) Portfolio albums (Facebook-style collections; independent of newsfeed)
-- ---------------------------------------------------------------------------
create table if not exists public.media_albums (
  id uuid primary key default gen_random_uuid(),
  owner_type text not null
    check (owner_type in ('user', 'business', 'professional')),
  owner_id uuid not null,
  title text not null,
  description text,
  cover_item_id uuid,
  sort_order integer not null default 0,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists media_albums_owner_idx
  on public.media_albums (owner_type, owner_id, sort_order);

create table if not exists public.media_album_items (
  id uuid primary key default gen_random_uuid(),
  album_id uuid not null references public.media_albums(id) on delete cascade,
  storage_path text not null,
  storage_provider text not null default 'supabase',
  media_type text not null default 'image'
    check (media_type in ('image', 'video')),
  caption text,
  sort_order integer not null default 0,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists media_album_items_album_idx
  on public.media_album_items (album_id, sort_order, created_at);

-- Optional cover FK (added after items exist).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'media_albums_cover_item_fk'
  ) then
    alter table public.media_albums
      add constraint media_albums_cover_item_fk
      foreign key (cover_item_id) references public.media_album_items(id)
      on delete set null;
  end if;
end $$;

alter table public.media_albums enable row level security;
alter table public.media_album_items enable row level security;

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
        where b.id = p_owner_id
          and b.created_by = auth.uid()
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
      where p.id = p_owner_id
        and p.profile_id = auth.uid()
    )
    else false
  end;
$$;

revoke all on function public.owns_media_album_owner(text, uuid) from public;
grant execute on function public.owns_media_album_owner(text, uuid) to authenticated;

drop policy if exists "Public read media albums" on public.media_albums;
create policy "Public read media albums"
  on public.media_albums for select to authenticated
  using (true);

drop policy if exists "Owners manage media albums" on public.media_albums;
create policy "Owners manage media albums"
  on public.media_albums for all to authenticated
  using (public.owns_media_album_owner(owner_type, owner_id))
  with check (
    created_by = auth.uid()
    and public.owns_media_album_owner(owner_type, owner_id)
  );

drop policy if exists "Public read media album items" on public.media_album_items;
create policy "Public read media album items"
  on public.media_album_items for select to authenticated
  using (true);

drop policy if exists "Owners manage media album items" on public.media_album_items;
create policy "Owners manage media album items"
  on public.media_album_items for all to authenticated
  using (
    exists (
      select 1 from public.media_albums a
      where a.id = media_album_items.album_id
        and public.owns_media_album_owner(a.owner_type, a.owner_id)
    )
  )
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.media_albums a
      where a.id = media_album_items.album_id
        and public.owns_media_album_owner(a.owner_type, a.owner_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Atomic avatar / cover replacement (avoids unique partial-index races)
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
  if p_media_role not in ('avatar', 'cover') then
    raise exception 'media_role must be avatar or cover';
  end if;

  if p_table = 'profile_media' and p_owner_column = 'profile_id' then
    v_allowed := p_owner_id = auth.uid();
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

  if not v_allowed and not public.is_firstvue_admin() then
    raise exception 'Not authorized to replace this media';
  end if;

  -- Deactivate/remove existing role rows first (satisfies one-active unique index).
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

revoke all on function public.replace_role_media(text, text, uuid, text, text, text, text) from public;
grant execute on function public.replace_role_media(text, text, uuid, text, text, text, text) to authenticated;

create or replace function public.replace_profile_avatar(
  p_profile_id uuid,
  p_storage_path text,
  p_storage_provider text default 'supabase',
  p_media_type text default 'image'
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.replace_role_media(
    'profile_media', 'profile_id', p_profile_id,
    p_storage_path, p_storage_provider, p_media_type, 'avatar'
  );
$$;

create or replace function public.replace_profile_cover(
  p_profile_id uuid,
  p_storage_path text,
  p_storage_provider text default 'supabase',
  p_media_type text default 'image'
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.replace_role_media(
    'profile_media', 'profile_id', p_profile_id,
    p_storage_path, p_storage_provider, p_media_type, 'cover'
  );
$$;

create or replace function public.replace_business_avatar(
  p_business_id uuid,
  p_storage_path text,
  p_storage_provider text default 'supabase',
  p_media_type text default 'image'
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.replace_role_media(
    'business_media', 'business_id', p_business_id,
    p_storage_path, p_storage_provider, p_media_type, 'avatar'
  );
$$;

create or replace function public.replace_business_cover(
  p_business_id uuid,
  p_storage_path text,
  p_storage_provider text default 'supabase',
  p_media_type text default 'image'
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.replace_role_media(
    'business_media', 'business_id', p_business_id,
    p_storage_path, p_storage_provider, p_media_type, 'cover'
  );
$$;

create or replace function public.replace_professional_avatar(
  p_professional_profile_id uuid,
  p_storage_path text,
  p_storage_provider text default 'supabase',
  p_media_type text default 'image'
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.replace_role_media(
    'professional_media', 'professional_profile_id', p_professional_profile_id,
    p_storage_path, p_storage_provider, p_media_type, 'avatar'
  );
$$;

create or replace function public.replace_professional_cover(
  p_professional_profile_id uuid,
  p_storage_path text,
  p_storage_provider text default 'supabase',
  p_media_type text default 'image'
)
returns uuid
language sql
security definer
set search_path = public
as $$
  select public.replace_role_media(
    'professional_media', 'professional_profile_id', p_professional_profile_id,
    p_storage_path, p_storage_provider, p_media_type, 'cover'
  );
$$;

revoke all on function public.replace_profile_avatar(uuid, text, text, text) from public;
revoke all on function public.replace_profile_cover(uuid, text, text, text) from public;
revoke all on function public.replace_business_avatar(uuid, text, text, text) from public;
revoke all on function public.replace_business_cover(uuid, text, text, text) from public;
revoke all on function public.replace_professional_avatar(uuid, text, text, text) from public;
revoke all on function public.replace_professional_cover(uuid, text, text, text) from public;

grant execute on function public.replace_profile_avatar(uuid, text, text, text) to authenticated;
grant execute on function public.replace_profile_cover(uuid, text, text, text) to authenticated;
grant execute on function public.replace_business_avatar(uuid, text, text, text) to authenticated;
grant execute on function public.replace_business_cover(uuid, text, text, text) to authenticated;
grant execute on function public.replace_professional_avatar(uuid, text, text, text) to authenticated;
grant execute on function public.replace_professional_cover(uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Harden Community creation approval (atomic + allow admin workflow)
-- ---------------------------------------------------------------------------
create or replace function public.review_community_creation_request(
  p_request_id uuid,
  p_approve boolean,
  p_denial_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.community_creation_requests%rowtype;
  v_hub_id uuid;
  v_admin_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_firstvue_admin() then
    raise exception 'Only FirstVue admins can review Community creation requests';
  end if;

  select * into v_req
  from public.community_creation_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Request not found';
  end if;

  if v_req.status <> 'pending' then
    raise exception 'Request is not pending (status=%)', v_req.status;
  end if;

  if not p_approve then
    update public.community_creation_requests
    set status = 'denied',
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        denial_reason = nullif(trim(coalesce(p_denial_reason, '')), '')
    where id = p_request_id;
    return null;
  end if;

  -- Prevent non-admin self-approval. Admins may approve their own request when
  -- they are the sole admin (Approval Center workflow), otherwise require a
  -- different admin.
  if v_req.requesting_user_id = auth.uid() then
    select count(*)::integer into v_admin_count
    from public.profiles
    where account_type = 'admin';
    if v_admin_count > 1 then
      raise exception
        'Another FirstVue admin must approve this Community creation request';
    end if;
  end if;

  begin
    insert into public.community_hubs (
      name,
      description,
      category,
      city,
      state,
      postal_code,
      created_by_profile_id,
      leader_user_id,
      status,
      creation_request_id,
      visibility
    ) values (
      v_req.proposed_name,
      v_req.description,
      v_req.category,
      v_req.city,
      v_req.state,
      v_req.postal_code,
      v_req.proposed_leader_user_id,
      v_req.proposed_leader_user_id,
      'active',
      v_req.id,
      'public'
    )
    returning id into v_hub_id;
  exception
    when unique_violation then
      raise exception 'A Community with this name or slug already exists';
  end;

  insert into public.community_hub_roles (hub_id, profile_id, role, status)
  values (v_hub_id, v_req.proposed_leader_user_id, 'creator', 'active')
  on conflict (hub_id, profile_id) do update
    set role = 'creator', status = 'active';

  insert into public.community_leaders (profile_id, approved_at, approved_by, status)
  values (v_req.proposed_leader_user_id, now(), auth.uid(), 'approved')
  on conflict (profile_id) do update
    set approved_at = excluded.approved_at,
        approved_by = excluded.approved_by,
        status = 'approved';

  update public.community_creation_requests
  set status = 'approved',
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      created_community_id = v_hub_id,
      denial_reason = null
  where id = p_request_id;

  return v_hub_id;
end;
$$;

revoke all on function public.review_community_creation_request(uuid, boolean, text) from public;
grant execute on function public.review_community_creation_request(uuid, boolean, text) to authenticated;

-- Align deny vocabulary: keep 'declined' for compatibility, also allow 'denied'.
do $$
begin
  alter table public.community_group_link_requests
    drop constraint if exists community_group_link_requests_status_check;
  alter table public.community_group_link_requests
    add constraint community_group_link_requests_status_check
    check (status in ('pending', 'approved', 'declined', 'denied', 'cancelled'));
exception when others then
  null;
end $$;

create or replace function public.review_community_group_link_request(
  p_request_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hub_id uuid;
  v_community_id uuid;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select hub_id, community_id, status
  into v_hub_id, v_community_id, v_status
  from public.community_group_link_requests
  where id = p_request_id
  for update;

  if v_hub_id is null then
    raise exception 'Link request not found';
  end if;

  if v_status is distinct from 'pending' then
    raise exception 'Request is not pending (status=%)', v_status;
  end if;

  if not (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.community_hub_roles r
      where r.hub_id = v_hub_id
        and r.profile_id = auth.uid()
        and r.status = 'active'
        and r.role in ('creator', 'lead_leader', 'leader', 'admin')
    )
  ) then
    raise exception 'Not authorized to review this link request';
  end if;

  update public.community_group_link_requests
  set
    status = case when p_approve then 'approved' else 'declined' end,
    reviewed_at = now(),
    reviewed_by = auth.uid()
  where id = p_request_id;

  if p_approve then
    update public.communities
    set hub_id = v_hub_id,
        updated_at = now()
    where id = v_community_id;
  end if;
end;
$$;

revoke all on function public.review_community_group_link_request(uuid, boolean) from public;
grant execute on function public.review_community_group_link_request(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) Visible Groups / Communities for a profile (privacy-aware)
-- ---------------------------------------------------------------------------
create or replace function public.fetch_profile_groups(p_profile_id uuid)
returns table (
  id uuid,
  name text,
  image_url text,
  privacy_type text,
  role text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    c.id,
    c.name,
    c.image_url,
    coalesce(c.privacy_type, 'public') as privacy_type,
    case
      when c.creator_id = p_profile_id then 'Group Leader'
      when m.role is not null then initcap(replace(m.role, '_', ' '))
      else 'Member'
    end as role
  from public.communities c
  left join public.community_members m
    on m.community_id = c.id
   and m.profile_id = p_profile_id
   and m.status = 'active'
  where (
      c.creator_id = p_profile_id
      or m.profile_id is not null
    )
    and (
      coalesce(c.privacy_type, 'public') = 'public'
      or p_profile_id = auth.uid()
      or public.is_firstvue_admin()
      or exists (
        select 1 from public.community_members viewer
        where viewer.community_id = c.id
          and viewer.profile_id = auth.uid()
          and viewer.status = 'active'
      )
    )
  order by c.name;
end;
$$;

create or replace function public.fetch_profile_communities(p_profile_id uuid)
returns table (
  id uuid,
  name text,
  image_url text,
  visibility text,
  role text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select
    h.id,
    h.name,
    h.image_url,
    h.visibility,
    case
      when h.leader_user_id = p_profile_id
        or h.created_by_profile_id = p_profile_id then 'Community Leader'
      when r.role is not null then initcap(replace(r.role, '_', ' '))
      when e.user_id is not null then 'Community Editor'
      else 'Member'
    end as role
  from public.community_hubs h
  left join public.community_hub_roles r
    on r.hub_id = h.id
   and r.profile_id = p_profile_id
   and r.status = 'active'
  left join public.community_editors e
    on e.community_id = h.id
   and e.user_id = p_profile_id
   and e.status = 'active'
  where (
      h.created_by_profile_id = p_profile_id
      or h.leader_user_id = p_profile_id
      or r.profile_id is not null
      or e.user_id is not null
    )
    and h.status = 'active'
    and (
      h.visibility = 'public'
      or p_profile_id = auth.uid()
      or public.is_firstvue_admin()
      or exists (
        select 1 from public.community_hub_roles viewer
        where viewer.hub_id = h.id
          and viewer.profile_id = auth.uid()
          and viewer.status = 'active'
      )
    )
  order by h.name;
end;
$$;

revoke all on function public.fetch_profile_groups(uuid) from public;
revoke all on function public.fetch_profile_communities(uuid) from public;
grant execute on function public.fetch_profile_groups(uuid) to authenticated;
grant execute on function public.fetch_profile_communities(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) RLS: only owners can post as business / professional
-- ---------------------------------------------------------------------------
create or replace function public.assert_can_post_as_identity(
  p_business_id uuid default null,
  p_professional_profile_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_business_id is not null then
    if not exists (
      select 1 from public.businesses b
      where b.id = p_business_id and b.created_by = auth.uid()
    ) and not exists (
      select 1 from public.business_memberships bm
      where bm.business_id = p_business_id
        and bm.profile_id = auth.uid()
        and bm.role in ('owner', 'manager')
    ) and not public.is_firstvue_admin() then
      raise exception 'Not authorized to post as this Business';
    end if;
  end if;

  if p_professional_profile_id is not null then
    if not exists (
      select 1 from public.professional_profiles p
      where p.id = p_professional_profile_id and p.profile_id = auth.uid()
    ) and not public.is_firstvue_admin() then
      raise exception 'Not authorized to post as this Professional profile';
    end if;
  end if;
end;
$$;

revoke all on function public.assert_can_post_as_identity(uuid, uuid) from public;
grant execute on function public.assert_can_post_as_identity(uuid, uuid) to authenticated;
