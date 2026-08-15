-- =============================================================================
-- FirstVue LIVE — ONE-SHOT apply (paste entire file in Supabase SQL Editor)
-- Safe to re-run. No now() in index predicates. No invalid array slices.
-- Covers: presence/hot, event geo, heat, ends_at, open sessions, realtime.
-- =============================================================================

-- 1) Presence + Hot
create table if not exists public.event_presence (
  event_id uuid not null references public.community_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  primary key (event_id, profile_id)
);

create index if not exists event_presence_event_idx
  on public.event_presence (event_id, expires_at desc);

alter table public.event_presence enable row level security;

drop policy if exists "Users read own event presence" on public.event_presence;
drop policy if exists "Authenticated read active event presence" on public.event_presence;
create policy "Users read own event presence"
  on public.event_presence for select to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Users delete own event presence" on public.event_presence;
create policy "Users delete own event presence"
  on public.event_presence for delete to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Users insert own event presence" on public.event_presence;
drop policy if exists "Users update own event presence" on public.event_presence;

create or replace function public.set_event_presence(p_event_id uuid)
returns public.event_presence
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_row public.event_presence;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not exists (
    select 1 from public.community_events e
    where e.id = p_event_id and e.status = 'approved'
  ) then raise exception 'Event not available'; end if;
  insert into public.event_presence as ep (event_id, profile_id, expires_at)
  values (p_event_id, v_uid, now() + interval '4 hours')
  on conflict (event_id, profile_id) do update
    set updated_at = now(), expires_at = now() + interval '4 hours'
  returning * into v_row;
  return v_row;
end;
$$;
grant execute on function public.set_event_presence(uuid) to authenticated;

create or replace function public.clear_event_presence(p_event_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  delete from public.event_presence
  where event_id = p_event_id and profile_id = auth.uid();
end;
$$;
grant execute on function public.clear_event_presence(uuid) to authenticated;

create or replace function public.event_here_now_count(p_event_id uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.event_presence
  where event_id = p_event_id and expires_at > now();
$$;
grant execute on function public.event_here_now_count(uuid) to authenticated, anon;

create table if not exists public.event_hot_reactions (
  event_id uuid not null references public.community_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

alter table public.event_hot_reactions enable row level security;

drop policy if exists "Users read own hot reactions" on public.event_hot_reactions;
drop policy if exists "Authenticated read event hot reactions" on public.event_hot_reactions;
create policy "Users read own hot reactions"
  on public.event_hot_reactions for select to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Users insert own hot reaction" on public.event_hot_reactions;
create policy "Users insert own hot reaction"
  on public.event_hot_reactions for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users delete own hot reaction" on public.event_hot_reactions;
create policy "Users delete own hot reaction"
  on public.event_hot_reactions for delete to authenticated
  using (profile_id = auth.uid());

create or replace function public.event_hot_count(p_event_id uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.event_hot_reactions where event_id = p_event_id;
$$;
grant execute on function public.event_hot_count(uuid) to authenticated, anon;

-- 2) Event geo + ends_at
alter table public.community_events
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists ends_at timestamptz;

create index if not exists community_events_geo_idx
  on public.community_events (latitude, longitude)
  where latitude is not null and longitude is not null;

create index if not exists community_events_lifecycle_idx
  on public.community_events (status, event_at, ends_at);

-- 3) Heat scores
create or replace function public.live_event_heat_scores(p_event_ids uuid[])
returns table (
  event_id uuid,
  score double precision,
  status text,
  going_recent int,
  here_now int,
  hot_recent int,
  vue_recent int
)
language sql stable security definer set search_path = public as $$
  with ids as (
    select distinct x.event_id
    from unnest(coalesce(p_event_ids, '{}'::uuid[])) as x(event_id)
    where x.event_id is not null
    limit 100
  ),
  scored as (
    select i.event_id,
      coalesce((select count(*) from public.event_attendance a
        where a.event_id = i.event_id and a.status = 'attending'
          and a.created_at > now() - interval '6 hours'), 0)::int as going_recent,
      coalesce((select count(*) from public.event_presence p
        where p.event_id = i.event_id and p.expires_at > now()), 0)::int as here_now,
      coalesce((select count(*) from public.event_hot_reactions h
        where h.event_id = i.event_id and h.created_at > now() - interval '6 hours'), 0)::int as hot_recent,
      coalesce((select count(*) from public.community_news_posts n
        where n.event_id = i.event_id and n.created_at > now() - interval '3 hours'), 0)::int as vue_recent
    from ids i
  )
  select s.event_id,
    (s.going_recent*2.0 + s.here_now*5.0 + s.hot_recent*1.5 + s.vue_recent*3.0)::float8,
    case
      when (s.going_recent*2.0 + s.here_now*5.0 + s.hot_recent*1.5 + s.vue_recent*3.0) >= 20
        and (s.here_now >= 2 or s.vue_recent >= 2) then 'hot'
      when (s.going_recent*2.0 + s.here_now*5.0 + s.hot_recent*1.5 + s.vue_recent*3.0) >= 8
        and (s.going_recent + s.here_now + s.hot_recent + s.vue_recent) >= 3 then 'heating_up'
      when (s.going_recent*2.0 + s.here_now*5.0 + s.hot_recent*1.5 + s.vue_recent*3.0) >= 3 then 'active'
      else null
    end,
    s.going_recent, s.here_now, s.hot_recent, s.vue_recent
  from scored s;
$$;
grant execute on function public.live_event_heat_scores(uuid[]) to authenticated, anon;

-- 4) Business open sessions (needs has_business_role)
create table if not exists public.business_open_sessions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  opened_by uuid not null references public.profiles(id) on delete cascade,
  note text,
  latitude double precision,
  longitude double precision,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_open_sessions_window check (ends_at > started_at),
  constraint business_open_sessions_max_window
    check (ends_at <= started_at + interval '12 hours')
);

create index if not exists business_open_sessions_business_ends_idx
  on public.business_open_sessions (business_id, ends_at desc);

create index if not exists business_open_sessions_ends_idx
  on public.business_open_sessions (ends_at desc);

alter table public.business_open_sessions enable row level security;

drop policy if exists "Read active business open sessions" on public.business_open_sessions;
create policy "Read active business open sessions"
  on public.business_open_sessions for select to authenticated, anon
  using (ends_at > now());

drop policy if exists "Owners delete own open sessions" on public.business_open_sessions;
create policy "Owners delete own open sessions"
  on public.business_open_sessions for delete to authenticated
  using (
    opened_by = auth.uid()
    or public.has_business_role(business_id, array['owner', 'manager']::text[], auth.uid())
  );

create or replace function public.start_business_open_session(
  p_business_id uuid,
  p_hours double precision default 4,
  p_note text default null,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns public.business_open_sessions
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_hours double precision := greatest(0.5, least(coalesce(p_hours, 4), 12));
  v_row public.business_open_sessions;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then raise exception 'Not allowed'; end if;
  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.status = 'approved'
  ) then raise exception 'Business not available'; end if;

  update public.business_open_sessions
  set ends_at = now(), updated_at = now()
  where business_id = p_business_id and ends_at > now();

  insert into public.business_open_sessions (
    business_id, opened_by, note, latitude, longitude, started_at, ends_at
  ) values (
    p_business_id, v_uid, nullif(trim(coalesce(p_note, '')), ''),
    p_latitude, p_longitude, now(),
    now() + make_interval(secs => (v_hours * 3600)::int)
  )
  returning * into v_row;
  return v_row;
end;
$$;
grant execute on function public.start_business_open_session(uuid, double precision, text, double precision, double precision) to authenticated;

create or replace function public.end_business_open_session(p_business_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], auth.uid()
  ) then raise exception 'Not allowed'; end if;
  update public.business_open_sessions
  set ends_at = now(), updated_at = now()
  where business_id = p_business_id and ends_at > now();
end;
$$;
grant execute on function public.end_business_open_session(uuid) to authenticated;

create or replace function public.list_active_business_open_sessions(p_limit int default 40)
returns table (
  session_id uuid,
  business_id uuid,
  business_name text,
  business_type text,
  note text,
  latitude double precision,
  longitude double precision,
  started_at timestamptz,
  ends_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    s.id, s.business_id, b.name, b.business_type, s.note,
    coalesce(s.latitude, (select bl.latitude from public.business_locations bl where bl.business_id = s.business_id limit 1)),
    coalesce(s.longitude, (select bl.longitude from public.business_locations bl where bl.business_id = s.business_id limit 1)),
    s.started_at, s.ends_at
  from public.business_open_sessions s
  join public.businesses b on b.id = s.business_id
  where s.ends_at > now() and b.status = 'approved'
  order by s.started_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
$$;
grant execute on function public.list_active_business_open_sessions(int) to authenticated, anon;

-- 5) Realtime publication
do $$
begin
  begin
    alter publication supabase_realtime add table public.business_open_sessions;
  exception when duplicate_object then null; when undefined_table then null; end;
  begin
    alter publication supabase_realtime add table public.event_presence;
  exception when duplicate_object then null; when undefined_table then null; end;
  begin
    alter publication supabase_realtime add table public.event_hot_reactions;
  exception when duplicate_object then null; when undefined_table then null; end;
end $$;
