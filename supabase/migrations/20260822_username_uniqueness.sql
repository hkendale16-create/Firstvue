-- Align username normalization with the Flutter client and add atomic set helper.

create or replace function public.normalize_username(raw text)
returns text
language sql
immutable
as $$
  select nullif(
    regexp_replace(
      lower(trim(regexp_replace(coalesce(raw, ''), '^@+', ''))),
      '[^a-z0-9_]', '', 'g'
    ),
    ''
  );
$$;

create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with normalized as (
    select public.normalize_username(candidate) as username
  )
  select
    n.username is not null
    and char_length(n.username) between 3 and 30
    and n.username ~ '^[a-z0-9_]+$'
    and not exists (
      select 1
      from public.profiles p
      where p.username = n.username
        and (auth.uid() is null or p.id <> auth.uid())
    )
  from normalized n;
$$;

create or replace function public.set_profile_username(candidate text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sign in to update your username.';
  end if;

  v_username := public.normalize_username(candidate);

  if v_username is null
     or char_length(v_username) < 3
     or char_length(v_username) > 30
     or v_username !~ '^[a-z0-9_]+$' then
    raise exception 'Username must be 3–30 characters: lowercase letters, numbers, and underscores only.';
  end if;

  if not public.is_username_available(v_username) then
    raise exception 'That username is already taken.';
  end if;

  insert into public.profiles (id, username, updated_at)
  values (v_uid, v_username, now())
  on conflict (id) do update
  set username = excluded.username,
      updated_at = excluded.updated_at;

  return v_username;
end;
$$;

revoke all on function public.set_profile_username(text) from public;
grant execute on function public.set_profile_username(text) to authenticated;
