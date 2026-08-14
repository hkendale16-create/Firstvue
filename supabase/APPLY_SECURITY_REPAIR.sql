-- FirstVue security repair — paste this ONE file in the SQL editor and click Run.
-- Project: sdssshegqdwobjelxzkp
-- Backup first. Safe to rerun. Do NOT disable RLS.
-- Combines 20260916 (profile cards) + 20260917 (tables, roles, DMs, realtime).

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


-- =============================================================================
-- FirstVue Repair 2 — missing tables, membership RPCs, graph RLS, realtime,
-- and stop new plaintext DM inserts (FV-H02, H03, H04, H05, H07, H13).
--
-- Apply AFTER 20260916_profiles_public_card_rls.sql.
-- Do NOT disable RLS. Do NOT drop unique avatar indexes.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A) Missing tables (idempotent)
-- ---------------------------------------------------------------------------
create table if not exists public.community_organizer_applications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null,
  organization_name text,
  reason text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.community_organizer_applications enable row level security;

drop policy if exists "Users create organizer applications" on public.community_organizer_applications;
create policy "Users create organizer applications"
  on public.community_organizer_applications for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users read own organizer applications" on public.community_organizer_applications;
create policy "Users read own organizer applications"
  on public.community_organizer_applications for select to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Admins manage organizer applications" on public.community_organizer_applications;
create policy "Admins manage organizer applications"
  on public.community_organizer_applications for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

create index if not exists community_organizer_applications_status_idx
  on public.community_organizer_applications (status, created_at desc);

create table if not exists public.feed_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  interaction_type text not null
    check (interaction_type in (
      'impression', 'view', 'spark', 'unspark', 'comment', 'save', 'unsave',
      'share', 'repost', 'skip', 'hide', 'not_interested', 'report',
      'watch', 'profile_visit', 'follow_from_feed'
    )),
  watch_time_ms integer not null default 0,
  completion_percent numeric(5,2),
  source_tab text not null default 'main'
    check (source_tab in (
      'main', 'community', 'group', 'trending', 'new', 'recommended',
      'profile', 'vue', 'other'
    )),
  session_id text,
  created_at timestamptz not null default now()
);

create index if not exists feed_interactions_user_created_idx
  on public.feed_interactions (user_id, created_at desc);
create index if not exists feed_interactions_post_type_idx
  on public.feed_interactions (post_id, interaction_type, created_at desc);
create index if not exists feed_interactions_user_type_idx
  on public.feed_interactions (user_id, interaction_type, created_at desc);
create index if not exists feed_interactions_session_idx
  on public.feed_interactions (session_id, created_at desc)
  where session_id is not null;

alter table public.feed_interactions enable row level security;

drop policy if exists "Users insert own feed interactions" on public.feed_interactions;
create policy "Users insert own feed interactions"
  on public.feed_interactions for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users read own feed interactions" on public.feed_interactions;
create policy "Users read own feed interactions"
  on public.feed_interactions for select to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- B) Owners grant/revoke team roles (never client-set role=owner)
-- ---------------------------------------------------------------------------
create or replace function public.grant_business_role(
  p_business_id uuid,
  p_profile_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(trim(coalesce(p_role, '')));
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if v_role not in (
    'manager', 'staff', 'content_editor', 'moderator', 'analytics_viewer'
  ) then
    raise exception 'Invalid business role';
  end if;
  if p_profile_id is null or p_business_id is null then
    raise exception 'business and profile are required';
  end if;
  if p_profile_id = auth.uid() then
    raise exception 'You cannot grant a role to yourself';
  end if;
  if not (
    public.is_firstvue_admin()
    or public.has_business_role(p_business_id, array['owner']::text[], auth.uid())
  ) then
    raise exception 'Not authorized to grant business roles';
  end if;

  insert into public.business_memberships (business_id, profile_id, role)
  values (p_business_id, p_profile_id, v_role)
  on conflict (business_id, profile_id) do update
    set role = excluded.role
    where public.business_memberships.role <> 'owner';
end;
$$;

create or replace function public.revoke_business_role(
  p_business_id uuid,
  p_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not (
    public.is_firstvue_admin()
    or public.has_business_role(p_business_id, array['owner']::text[], auth.uid())
  ) then
    raise exception 'Not authorized to revoke business roles';
  end if;

  delete from public.business_memberships
  where business_id = p_business_id
    and profile_id = p_profile_id
    and role <> 'owner';
end;
$$;

revoke all on function public.grant_business_role(uuid, uuid, text) from public;
revoke all on function public.revoke_business_role(uuid, uuid) from public;
grant execute on function public.grant_business_role(uuid, uuid, text) to authenticated;
grant execute on function public.revoke_business_role(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- C) Stop new plaintext DMs (history remains readable by participants)
-- ---------------------------------------------------------------------------
drop policy if exists "Participants send messages in their threads" on public.direct_messages;

-- ---------------------------------------------------------------------------
-- D) Social graph SELECT — participants / public entities, not using(true)
-- ---------------------------------------------------------------------------
create or replace function public.is_community_member(
  p_community_id uuid,
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
      select 1 from public.community_members m
      where m.community_id = p_community_id
        and m.profile_id = p_profile_id
        and coalesce(m.status, 'active') = 'active'
    ),
    false
  );
$$;

revoke all on function public.is_community_member(uuid, uuid) from public;
grant execute on function public.is_community_member(uuid, uuid) to authenticated;

drop policy if exists "Authenticated read community members" on public.community_members;
drop policy if exists "Members read community members" on public.community_members;
create policy "Members read community members"
  on public.community_members for select to authenticated
  using (
    profile_id = auth.uid()
    or public.is_firstvue_admin()
    or public.is_community_member(community_id, auth.uid())
    or exists (
      select 1 from public.communities c
      where c.id = community_members.community_id
        and coalesce(c.privacy_type, 'public') = 'public'
    )
  );

drop policy if exists "Authenticated read follows" on public.profile_follows;
drop policy if exists "Authenticated read profile follows" on public.profile_follows;
drop policy if exists "Users read follows they participate in" on public.profile_follows;
create policy "Users read follows they participate in"
  on public.profile_follows for select to authenticated
  using (
    follower_id = auth.uid()
    or following_id = auth.uid()
    or public.is_firstvue_admin()
  );

create or replace function public.count_profile_followers(p_profile_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.profile_follows
  where following_id = p_profile_id;
$$;

create or replace function public.count_profile_following(p_profile_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.profile_follows
  where follower_id = p_profile_id;
$$;

revoke all on function public.count_profile_followers(uuid) from public;
revoke all on function public.count_profile_following(uuid) from public;
grant execute on function public.count_profile_followers(uuid) to authenticated;
grant execute on function public.count_profile_following(uuid) to authenticated;

drop policy if exists "Authenticated read community follows" on public.community_follows;
drop policy if exists "Users read community follows they participate in" on public.community_follows;
create policy "Users read community follows they participate in"
  on public.community_follows for select to authenticated
  using (
    profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.communities c
      where c.id = community_follows.community_id
        and coalesce(c.privacy_type, 'public') = 'public'
    )
  );

-- ---------------------------------------------------------------------------
-- E) Realtime for messaging / notifications
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'fv_msg_messages',
    'direct_messages',
    'fv_msg_calls',
    'activity_notifications'
  ]
  loop
    if to_regclass('public.' || t) is not null
       and not exists (
         select 1
         from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = t
       ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        t
      );
    end if;
  end loop;
end $$;

notify pgrst, 'reload schema';
