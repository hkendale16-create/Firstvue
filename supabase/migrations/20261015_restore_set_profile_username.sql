-- Restore set_profile_username used by Edit Profile saves.
-- Live DB had normalize_username / is_username_available but was missing
-- this RPC, so every profile save failed before display_name could update.

create or replace function public.set_profile_username(candidate text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text;
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Sign in to update your username.';
  end if;

  v_username := public.normalize_username(candidate);
  if v_username is null
     or char_length(v_username) not between 3 and 30
     or v_username !~ '^[a-z0-9_]+$' then
    raise exception 'Username must be 3-30 lowercase letters, numbers, or underscores.';
  end if;

  insert into public.profiles (id, username, updated_at)
  values (v_uid, v_username, now())
  on conflict (id) do update
    set username = excluded.username,
        updated_at = excluded.updated_at
    where public.profiles.id = v_uid;

  return v_username;
exception
  when unique_violation then
    raise exception 'That username is already taken.' using errcode = '23505';
end;
$$;

revoke all on function public.set_profile_username(text) from public;
grant execute on function public.set_profile_username(text) to authenticated;
