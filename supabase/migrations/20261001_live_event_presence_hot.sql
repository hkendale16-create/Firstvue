-- =============================================================================
-- FirstVue LIVE Phase 3: event presence (I'm Here) + Hot reactions
-- Additive + reversible. No GPS columns. Presence is time-limited.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- event_presence: voluntary "I'm Here" (not GPS broadcast)
-- ---------------------------------------------------------------------------
create table if not exists public.event_presence (
  event_id uuid not null references public.community_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  primary key (event_id, profile_id),
  constraint event_presence_expires_after_created
    check (expires_at > created_at),
  constraint event_presence_max_window
    check (expires_at <= created_at + interval '12 hours')
);

-- No `where expires_at > now()` — now() is not IMMUTABLE, so Postgres rejects it
-- in a partial-index predicate.
create index if not exists event_presence_active_idx
  on public.event_presence (event_id, expires_at desc);

create index if not exists event_presence_profile_idx
  on public.event_presence (profile_id, expires_at desc);

alter table public.event_presence enable row level security;

drop policy if exists "Authenticated read active event presence" on public.event_presence;
create policy "Authenticated read active event presence"
  on public.event_presence for select to authenticated
  using (expires_at > now() or profile_id = auth.uid());

drop policy if exists "Users insert own event presence" on public.event_presence;
create policy "Users insert own event presence"
  on public.event_presence for insert to authenticated
  with check (
    profile_id = auth.uid()
    and expires_at > now()
    and expires_at <= now() + interval '12 hours'
  );

drop policy if exists "Users update own event presence" on public.event_presence;
create policy "Users update own event presence"
  on public.event_presence for update to authenticated
  using (profile_id = auth.uid())
  with check (
    profile_id = auth.uid()
    and expires_at > now()
    and expires_at <= now() + interval '12 hours'
  );

drop policy if exists "Users delete own event presence" on public.event_presence;
create policy "Users delete own event presence"
  on public.event_presence for delete to authenticated
  using (profile_id = auth.uid());

-- Force ownership + expiry window server-side on write.
create or replace function public.set_event_presence(p_event_id uuid)
returns public.event_presence
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.event_presence;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if p_event_id is null then
    raise exception 'event_id required';
  end if;
  if not exists (
    select 1 from public.community_events e
    where e.id = p_event_id and e.status = 'approved'
  ) then
    raise exception 'Event not available';
  end if;

  insert into public.event_presence as ep (event_id, profile_id, created_at, updated_at, expires_at)
  values (p_event_id, v_uid, now(), now(), now() + interval '4 hours')
  on conflict (event_id, profile_id) do update
    set updated_at = now(),
        expires_at = now() + interval '4 hours'
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.set_event_presence(uuid) from public;
grant execute on function public.set_event_presence(uuid) to authenticated;

create or replace function public.clear_event_presence(p_event_id uuid)
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
  delete from public.event_presence
  where event_id = p_event_id and profile_id = v_uid;
end;
$$;

revoke all on function public.clear_event_presence(uuid) from public;
grant execute on function public.clear_event_presence(uuid) to authenticated;

create or replace function public.event_here_now_count(p_event_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.event_presence
  where event_id = p_event_id
    and expires_at > now();
$$;

revoke all on function public.event_here_now_count(uuid) from public;
grant execute on function public.event_here_now_count(uuid) to authenticated, anon;

-- ---------------------------------------------------------------------------
-- event_hot_reactions: distinct from attendance / presence
-- ---------------------------------------------------------------------------
create table if not exists public.event_hot_reactions (
  event_id uuid not null references public.community_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

create index if not exists event_hot_reactions_event_idx
  on public.event_hot_reactions (event_id, created_at desc);

alter table public.event_hot_reactions enable row level security;

drop policy if exists "Authenticated read event hot reactions" on public.event_hot_reactions;
create policy "Authenticated read event hot reactions"
  on public.event_hot_reactions for select to authenticated
  using (true);

drop policy if exists "Users insert own hot reaction" on public.event_hot_reactions;
create policy "Users insert own hot reaction"
  on public.event_hot_reactions for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users delete own hot reaction" on public.event_hot_reactions;
create policy "Users delete own hot reaction"
  on public.event_hot_reactions for delete to authenticated
  using (profile_id = auth.uid());
