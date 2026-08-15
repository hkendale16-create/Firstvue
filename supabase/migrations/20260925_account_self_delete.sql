-- Account self-deletion RPC (no Edge Function required).
-- See also supabase/APPLY_ACCOUNT_SELF_DELETE.sql

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

  perform public.delete_my_account_data(v_uid);

  delete from auth.users where id = v_uid;

  if not found then
    raise exception 'Unable to delete authentication account'
      using errcode = 'P0001';
  end if;

  return jsonb_build_object('deleted', true, 'blocked', false);
end;
$$;

comment on function public.delete_my_account() is
  'Self-service account deletion for the signed-in user.';

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

notify pgrst, 'reload schema';
