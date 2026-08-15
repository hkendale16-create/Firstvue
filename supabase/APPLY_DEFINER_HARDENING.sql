-- FirstVue SECURITY DEFINER EXECUTE hardening — paste in Supabase SQL editor and Run.
-- Project: sdssshegqdwobjelxzkp
-- Safe to rerun. Uses to_regprocedure guards for optional functions.
-- Same content as supabase/migrations/20260924_definer_execute_hardening.sql

-- =============================================================================
-- FirstVue SECURITY DEFINER EXECUTE hardening (2026-09-24)
--
-- Tightens EXECUTE grants on sensitive helpers so publishable (anon) and
-- authenticated clients cannot invoke internal/service-only RPCs directly.
-- RLS policies that reference boolean helpers still work: the invoker role
-- must retain EXECUTE when it SELECTs tables whose policies call the helper.
--
-- Manual step (cannot be set via SQL):
--   Supabase Dashboard → Authentication → Settings → enable
--   "Leaked password protection" (HaveIBeenPwned).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Internal messaging helper — not callable from clients
--    Used only inside other SECURITY DEFINER functions (owner bypasses grant).
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.fv_msg_is_under_13(uuid)') is not null then
    revoke all on function public.fv_msg_is_under_13(uuid)
      from public, anon, authenticated;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Auth email resolver — Edge Function / service_role only
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.auth_email_for_username(text)') is not null then
    revoke all on function public.auth_email_for_username(text)
      from public, anon, authenticated;
    grant execute on function public.auth_email_for_username(text)
      to service_role;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3) Email pipeline internals — trigger/service paths only
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.get_auth_user_email(uuid)') is not null then
    revoke all on function public.get_auth_user_email(uuid)
      from public, anon, authenticated;
    grant execute on function public.get_auth_user_email(uuid)
      to service_role;
  end if;
end $$;

do $$
begin
  if to_regprocedure(
    'public.enqueue_email_notification(text, text, jsonb, text)'
  ) is not null then
    revoke all on function public.enqueue_email_notification(
      text, text, jsonb, text
    ) from public, anon, authenticated;
    grant execute on function public.enqueue_email_notification(
      text, text, jsonb, text
    ) to service_role;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4) Stripe webhook sync — service_role only (Edge Function caller)
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure(
    'public.sync_business_subscription_from_stripe(uuid, text, integer, text, text, text, timestamptz)'
  ) is not null then
    revoke all on function public.sync_business_subscription_from_stripe(
      uuid, text, integer, text, text, text, timestamptz
    ) from public, anon, authenticated;
    grant execute on function public.sync_business_subscription_from_stripe(
      uuid, text, integer, text, text, text, timestamptz
    ) to service_role;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5) RLS boolean oracles — revoke overbroad anon where not needed
--
--    KEEP anon EXECUTE:
--      * has_hub_role — anon SELECT on community_hubs policy calls it
--      * is_community_member — anon SELECT on communities (discovery) calls it
--
--    REVOKE anon EXECUTE (authenticated-only paths / direct Flutter RPC):
--      * is_active_hub_manager — Flutter calls as authenticated; hub write RLS
--      * has_business_role — business membership policies are authenticated-only
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.is_active_hub_manager(uuid, uuid)') is not null then
    revoke all on function public.is_active_hub_manager(uuid, uuid)
      from public, anon;
    grant execute on function public.is_active_hub_manager(uuid, uuid)
      to authenticated;
  end if;
end $$;

do $$
begin
  if to_regprocedure('public.has_business_role(uuid, text[], uuid)') is not null then
    revoke all on function public.has_business_role(uuid, text[], uuid)
      from public, anon;
    grant execute on function public.has_business_role(uuid, text[], uuid)
      to authenticated;
  end if;
end $$;

-- has_hub_role + is_community_member: re-assert minimal grants (anon kept for discovery RLS).
do $$
begin
  if to_regprocedure('public.has_hub_role(uuid, uuid, boolean)') is not null then
    revoke all on function public.has_hub_role(uuid, uuid, boolean)
      from public;
    grant execute on function public.has_hub_role(uuid, uuid, boolean)
      to anon, authenticated;
  end if;
end $$;

do $$
begin
  if to_regprocedure('public.is_community_member(uuid, uuid)') is not null then
    revoke all on function public.is_community_member(uuid, uuid)
      from public;
    grant execute on function public.is_community_member(uuid, uuid)
      to anon, authenticated;
  end if;
end $$;

notify pgrst, 'reload schema';
