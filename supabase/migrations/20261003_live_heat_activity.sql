-- =============================================================================
-- FirstVue LIVE Phase 5: Heating Up activity score (server-side, time-decayed)
-- Additive. Does not use lifetime likes as the primary signal.
-- =============================================================================

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
language sql
stable
security definer
set search_path = public
as $$
  with ids as (
    select distinct unnest(p_event_ids) as event_id
  ),
  going as (
    select a.event_id, count(*)::int as c
    from public.event_attendance a
    join ids i on i.event_id = a.event_id
    where a.status = 'attending'
      and a.created_at > now() - interval '6 hours'
    group by a.event_id
  ),
  presence as (
    select p.event_id, count(*)::int as c
    from public.event_presence p
    join ids i on i.event_id = p.event_id
    where p.expires_at > now()
    group by p.event_id
  ),
  hot as (
    select h.event_id, count(*)::int as c
    from public.event_hot_reactions h
    join ids i on i.event_id = h.event_id
    where h.created_at > now() - interval '6 hours'
    group by h.event_id
  ),
  vues as (
    select n.event_id, count(*)::int as c
    from public.community_news_posts n
    join ids i on i.event_id = n.event_id
    where n.event_id is not null
      and n.created_at > now() - interval '3 hours'
    group by n.event_id
  ),
  scored as (
    select
      i.event_id,
      coalesce(g.c, 0) as going_recent,
      coalesce(p.c, 0) as here_now,
      coalesce(h.c, 0) as hot_recent,
      coalesce(v.c, 0) as vue_recent,
      (
        coalesce(g.c, 0) * 2.0 +
        coalesce(p.c, 0) * 5.0 +
        coalesce(h.c, 0) * 1.5 +
        coalesce(v.c, 0) * 3.0
      )::double precision as score
    from ids i
    left join going g on g.event_id = i.event_id
    left join presence p on p.event_id = i.event_id
    left join hot h on h.event_id = i.event_id
    left join vues v on v.event_id = i.event_id
  )
  select
    s.event_id,
    s.score,
    case
      when s.score >= 20 and (s.here_now >= 2 or s.vue_recent >= 2) then 'hot'
      when s.score >= 8 and (s.going_recent + s.here_now + s.hot_recent + s.vue_recent) >= 3
        then 'heating_up'
      when s.score >= 3 then 'active'
      else null
    end as status,
    s.going_recent,
    s.here_now,
    s.hot_recent,
    s.vue_recent
  from scored s;
$$;

revoke all on function public.live_event_heat_scores(uuid[]) from public;
grant execute on function public.live_event_heat_scores(uuid[]) to authenticated, anon;

comment on function public.live_event_heat_scores(uuid[]) is
  'LIVE heat scores from recent Going / Here Now / Hot / VUEs with thresholds. Null status = insufficient activity.';
