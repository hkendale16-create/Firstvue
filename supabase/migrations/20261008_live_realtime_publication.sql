-- =============================================================================
-- FirstVue LIVE Phase 10: enable Realtime for LIVE tables
-- Additive. Safe if already added (catch duplicate_object).
-- =============================================================================

do $$
begin
  begin
    alter publication supabase_realtime add table public.business_open_sessions;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;
  begin
    alter publication supabase_realtime add table public.event_presence;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;
  begin
    alter publication supabase_realtime add table public.event_hot_reactions;
  exception
    when duplicate_object then null;
    when undefined_table then null;
  end;
end $$;
