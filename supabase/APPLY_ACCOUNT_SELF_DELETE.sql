-- Paste into Supabase SQL Editor and Run.
-- Account self-deletion without Edge Function (safe to re-run).
-- Deletes personal data + auth.users for auth.uid() only.
-- Still blocks if the user owns businesses / sole hubs / rentals.

create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
  v_blockers jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  v_blockers := public.get_account_deletion_blockers(v_uid);
  if coalesce((v_blockers->>'blocked')::boolean, false) then
    return v_blockers || jsonb_build_object('deleted', false);
  end if;

  -- Clean personal data first (service helper expects explicit id).
  perform public.delete_my_account_data(v_uid);

  -- Remove Auth user (profiles cascade via FK where configured).
  delete from auth.users where id = v_uid;

  if not found then
    raise exception 'Unable to delete authentication account'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object('deleted', true, 'blocked', false);
end;
$$;

comment on function public.delete_my_account() is
  'Self-service account deletion for the signed-in user. Prefer over Edge Function when undeployed.';

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

-- Allow the authenticated self-cleanup path used above.
revoke all on function public.delete_my_account_data(uuid) from public;
grant execute on function public.delete_my_account_data(uuid) to service_role;
-- Keep delete_my_account_data callable only via delete_my_account / service_role.
-- delete_my_account is SECURITY DEFINER so it can call delete_my_account_data without client GRANT.

notify pgrst, 'reload schema';
