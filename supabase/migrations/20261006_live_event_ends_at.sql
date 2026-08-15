-- =============================================================================
-- FirstVue LIVE Phase 7: optional event ends_at for honest LIVE / ENDING SOON
-- Additive. No now() in index predicates.
-- =============================================================================

alter table public.community_events
  add column if not exists ends_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'community_events_ends_after_start'
  ) then
    alter table public.community_events
      add constraint community_events_ends_after_start
      check (ends_at is null or event_at is null or ends_at > event_at);
  end if;
end $$;

create index if not exists community_events_lifecycle_idx
  on public.community_events (status, event_at, ends_at);

comment on column public.community_events.ends_at is
  'Optional event end. When set, LIVE badges use ends_at instead of the start-only heuristic.';
