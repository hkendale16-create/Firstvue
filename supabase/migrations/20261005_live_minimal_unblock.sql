-- Minimal LIVE unblock (safe to re-run). No partial indexes with now().

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

-- No direct insert/update policies — use RPCs below.

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

alter table public.community_events
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

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
    select
      i.event_id,
      coalesce((
        select count(*) from public.event_attendance a
        where a.event_id = i.event_id and a.status = 'attending'
          and a.created_at > now() - interval '6 hours'
      ), 0)::int as going_recent,
      coalesce((
        select count(*) from public.event_presence p
        where p.event_id = i.event_id and p.expires_at > now()
      ), 0)::int as here_now,
      coalesce((
        select count(*) from public.event_hot_reactions h
        where h.event_id = i.event_id and h.created_at > now() - interval '6 hours'
      ), 0)::int as hot_recent,
      coalesce((
        select count(*) from public.community_news_posts n
        where n.event_id = i.event_id and n.created_at > now() - interval '3 hours'
      ), 0)::int as vue_recent
    from ids i
  )
  select
    s.event_id,
    (s.going_recent * 2.0 + s.here_now * 5.0 + s.hot_recent * 1.5 + s.vue_recent * 3.0)::float8,
    case
      when (s.going_recent * 2.0 + s.here_now * 5.0 + s.hot_recent * 1.5 + s.vue_recent * 3.0) >= 20
        and (s.here_now >= 2 or s.vue_recent >= 2) then 'hot'
      when (s.going_recent * 2.0 + s.here_now * 5.0 + s.hot_recent * 1.5 + s.vue_recent * 3.0) >= 8
        and (s.going_recent + s.here_now + s.hot_recent + s.vue_recent) >= 3 then 'heating_up'
      when (s.going_recent * 2.0 + s.here_now * 5.0 + s.hot_recent * 1.5 + s.vue_recent * 3.0) >= 3
        then 'active'
      else null
    end,
    s.going_recent, s.here_now, s.hot_recent, s.vue_recent
  from scored s;
$$;
grant execute on function public.live_event_heat_scores(uuid[]) to authenticated, anon;
