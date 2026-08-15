-- =============================================================================
-- FirstVue LIVE Phase 8: business / food truck open sessions
-- Time-bounded operator check-ins. No fabricated social proof. No now() indexes.
-- =============================================================================

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
  constraint business_open_sessions_window
    check (ends_at > started_at),
  constraint business_open_sessions_max_window
    check (ends_at <= started_at + interval '12 hours')
);

create index if not exists business_open_sessions_business_ends_idx
  on public.business_open_sessions (business_id, ends_at desc);

create index if not exists business_open_sessions_ends_idx
  on public.business_open_sessions (ends_at desc);

alter table public.business_open_sessions enable row level security;

-- Active sessions readable by anyone (public LIVE map / home).
drop policy if exists "Read active business open sessions" on public.business_open_sessions;
create policy "Read active business open sessions"
  on public.business_open_sessions for select to authenticated, anon
  using (ends_at > now());

-- Operators manage own rows only via RPCs (no direct insert/update policies).
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
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_hours double precision := greatest(0.5, least(coalesce(p_hours, 4), 12));
  v_row public.business_open_sessions;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_business_id is null then
    raise exception 'business_id required';
  end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then
    raise exception 'Not allowed';
  end if;
  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.status = 'approved'
  ) then
    raise exception 'Business not available';
  end if;

  -- Close any still-active session for this business first.
  update public.business_open_sessions
  set ends_at = now(), updated_at = now()
  where business_id = p_business_id
    and ends_at > now();

  insert into public.business_open_sessions (
    business_id, opened_by, note, latitude, longitude, started_at, ends_at
  ) values (
    p_business_id,
    v_uid,
    nullif(trim(coalesce(p_note, '')), ''),
    p_latitude,
    p_longitude,
    now(),
    now() + make_interval(secs => (v_hours * 3600)::int)
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.start_business_open_session(uuid, double precision, text, double precision, double precision) from public;
grant execute on function public.start_business_open_session(uuid, double precision, text, double precision, double precision) to authenticated;

create or replace function public.end_business_open_session(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.has_business_role(
    p_business_id, array['owner', 'manager']::text[], v_uid
  ) then
    raise exception 'Not allowed';
  end if;

  update public.business_open_sessions
  set ends_at = now(), updated_at = now()
  where business_id = p_business_id
    and ends_at > now();
end;
$$;

revoke all on function public.end_business_open_session(uuid) from public;
grant execute on function public.end_business_open_session(uuid) to authenticated;

create or replace function public.list_active_business_open_sessions(
  p_limit int default 40
)
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
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id as session_id,
    s.business_id,
    b.name as business_name,
    b.business_type,
    s.note,
    coalesce(
      s.latitude,
      (select bl.latitude from public.business_locations bl
       where bl.business_id = s.business_id limit 1)
    ) as latitude,
    coalesce(
      s.longitude,
      (select bl.longitude from public.business_locations bl
       where bl.business_id = s.business_id limit 1)
    ) as longitude,
    s.started_at,
    s.ends_at
  from public.business_open_sessions s
  join public.businesses b on b.id = s.business_id
  where s.ends_at > now()
    and b.status = 'approved'
  order by s.started_at desc
  limit greatest(1, least(coalesce(p_limit, 40), 100));
$$;

revoke all on function public.list_active_business_open_sessions(int) from public;
grant execute on function public.list_active_business_open_sessions(int) to authenticated, anon;

comment on table public.business_open_sessions is
  'LIVE operator open check-ins for businesses / food trucks. Max 12h. No GPS forced.';
