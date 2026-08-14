-- Secure authentication support for username login and required signup profile data.
-- This migration is intentionally the single auth migration for this change.

alter table public.profiles
  add column if not exists terms_accepted_at timestamptz,
  add column if not exists privacy_accepted_at timestamptz;

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

create or replace function public.handle_firstvue_auth_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
  v_username text := public.normalize_username(
    new.raw_user_meta_data ->> 'username'
  );
  v_terms boolean := coalesce(
    (new.raw_user_meta_data ->> 'terms_accepted')::boolean,
    false
  );
  v_privacy boolean := coalesce(
    (new.raw_user_meta_data ->> 'privacy_accepted')::boolean,
    false
  );
begin
  if v_provider = 'email' then
    if v_username is null
       or char_length(v_username) not between 3 and 30
       or v_username !~ '^[a-z0-9_]+$'
       or not v_terms
       or not v_privacy then
      raise exception 'Unable to create account.';
    end if;
  end if;

  insert into public.profiles (
    id,
    display_name,
    username,
    account_type,
    terms_accepted_at,
    privacy_accepted_at
  )
  values (
    new.id,
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    v_username,
    'customer',
    case when v_terms then now() else null end,
    case when v_privacy then now() else null end
  )
  on conflict (id) do update
    set username = coalesce(public.profiles.username, excluded.username),
        terms_accepted_at = coalesce(
          public.profiles.terms_accepted_at,
          excluded.terms_accepted_at
        ),
        privacy_accepted_at = coalesce(
          public.profiles.privacy_accepted_at,
          excluded.privacy_accepted_at
        ),
        updated_at = now();

  return new;
exception
  when unique_violation then
    raise exception 'Unable to create account.' using errcode = '23505';
end;
$$;

revoke all on function public.handle_firstvue_auth_signup() from public;

drop trigger if exists on_auth_user_created_firstvue on auth.users;
create trigger on_auth_user_created_firstvue
  after insert on auth.users
  for each row execute function public.handle_firstvue_auth_signup();

-- This resolver is callable only with the Edge Function's service-role key.
-- It is never granted to anon/authenticated and its result never reaches Flutter.
create or replace function public.auth_email_for_username(candidate text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select u.email::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.username = public.normalize_username(candidate)
    and u.deleted_at is null
  limit 1;
$$;

revoke all on function public.auth_email_for_username(text) from public;
grant execute on function public.auth_email_for_username(text) to service_role;
