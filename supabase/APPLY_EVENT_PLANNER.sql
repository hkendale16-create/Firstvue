-- Paste this entire file into Supabase SQL Editor and Run.
--
-- FirstVue — Event Planner schema extensions
-- Safe to re-run. Parent agent may fold into a migration bundle.
-- =============================================================================

-- Extend community_events.status to support drafts + cancellations used by Event Planner.
alter table public.community_events
  drop constraint if exists community_events_status_check;

alter table public.community_events
  add constraint community_events_status_check
  check (
    status in (
      'pending',
      'approved',
      'rejected',
      'cancelled',
      'draft'
    )
  );

-- Organizers can read their own events regardless of status (draft/cancelled included).
drop policy if exists "Authenticated read approved events" on public.community_events;
drop policy if exists "Public reads approved events" on public.community_events;

create policy "Authenticated read approved events"
  on public.community_events for select to authenticated
  using (status = 'approved' or organizer_id = auth.uid());

create policy "Public reads approved events"
  on public.community_events for select to anon
  using (status = 'approved');

-- Authors manage their own events (update draft/publish/cancel).
drop policy if exists "Authors manage their events" on public.community_events;
create policy "Authors manage their events"
  on public.community_events for update to authenticated
  using (organizer_id = auth.uid())
  with check (organizer_id = auth.uid());

create index if not exists community_events_organizer_idx
  on public.community_events (organizer_id, created_at desc);

notify pgrst, 'reload schema';
