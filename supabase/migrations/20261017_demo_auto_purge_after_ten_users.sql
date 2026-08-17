-- Auto-purge the fvdemo_* pack once 10 real (non-demo) users have signed up.
-- Also exposes a public status RPC so the auth UI can show demo credentials
-- only while the pack still exists.

create or replace function public.fv_real_user_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.profiles p
  left join auth.users u on u.id = p.id
  where coalesce(p.is_demo, false) = false
    and coalesce(p.username, '') not like 'fvdemo_%'
    and coalesce(u.email, '') not like '%@firstvue.demo'
    and u.deleted_at is null;
$$;

revoke all on function public.fv_real_user_count() from public;
grant execute on function public.fv_real_user_count() to service_role;

create or replace function public.fv_purge_demo_pack()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_demo_ids uuid[];
  v_before int;
  v_after int;
begin
  select coalesce(array_agg(id), '{}'::uuid[])
  into v_demo_ids
  from public.profiles
  where coalesce(is_demo, false) = true
     or username like 'fvdemo_%';

  v_before := coalesce(cardinality(v_demo_ids), 0);
  if v_before = 0 then
    return jsonb_build_object('purged', false, 'removed', 0);
  end if;

  delete from public.community_news_post_media
  where post_id in (
    select id from public.community_news_posts
    where coalesce(is_demo, false) = true
       or author_id = any (v_demo_ids)
  );

  delete from public.community_news_posts
  where coalesce(is_demo, false) = true
     or author_id = any (v_demo_ids);

  delete from public.community_events
  where coalesce(is_demo, false) = true
     or organizer_id = any (v_demo_ids);

  delete from public.business_media
  where business_id in (
    select id from public.businesses
    where coalesce(is_demo, false) = true
       or created_by = any (v_demo_ids)
  );

  delete from public.business_locations
  where business_id in (
    select id from public.businesses
    where coalesce(is_demo, false) = true
       or created_by = any (v_demo_ids)
  );

  delete from public.business_memberships
  where profile_id = any (v_demo_ids)
     or business_id in (
       select id from public.businesses
       where coalesce(is_demo, false) = true
          or created_by = any (v_demo_ids)
     );

  delete from public.businesses
  where coalesce(is_demo, false) = true
     or created_by = any (v_demo_ids);

  delete from public.profile_media
  where profile_id = any (v_demo_ids);

  delete from public.community_organizers
  where profile_id = any (v_demo_ids);

  delete from auth.identities
  where user_id = any (v_demo_ids);

  delete from auth.users
  where id = any (v_demo_ids);

  select count(*)::int
  into v_after
  from public.profiles
  where coalesce(is_demo, false) = true
     or username like 'fvdemo_%';

  return jsonb_build_object(
    'purged', true,
    'removed', v_before,
    'remaining', v_after
  );
end;
$$;

comment on function public.fv_purge_demo_pack() is
  'Deletes the seeded fvdemo_* pack (profiles, content, auth users). Safe for real accounts.';

revoke all on function public.fv_purge_demo_pack() from public;
grant execute on function public.fv_purge_demo_pack() to service_role;

create or replace function public.fv_maybe_purge_demo_pack()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_threshold constant int := 10;
  v_real int;
  v_demo int;
begin
  select count(*)::int
  into v_demo
  from public.profiles
  where coalesce(is_demo, false) = true
     or username like 'fvdemo_%';

  if v_demo = 0 then
    return jsonb_build_object(
      'purged', false,
      'reason', 'no_demos',
      'real_users', public.fv_real_user_count(),
      'threshold', v_threshold
    );
  end if;

  v_real := public.fv_real_user_count();
  if v_real < v_threshold then
    return jsonb_build_object(
      'purged', false,
      'reason', 'below_threshold',
      'real_users', v_real,
      'threshold', v_threshold,
      'demo_users', v_demo
    );
  end if;

  return public.fv_purge_demo_pack()
    || jsonb_build_object(
      'reason', 'threshold_met',
      'real_users', v_real,
      'threshold', v_threshold
    );
end;
$$;

comment on function public.fv_maybe_purge_demo_pack() is
  'Purges demo accounts once at least 10 real users have signed up.';

revoke all on function public.fv_maybe_purge_demo_pack() from public;
grant execute on function public.fv_maybe_purge_demo_pack() to service_role;

create or replace function public.fv_trg_maybe_purge_demos_on_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
begin
  if coalesce(new.is_demo, false) then
    return new;
  end if;
  if coalesce(new.username, '') like 'fvdemo_%' then
    return new;
  end if;

  select u.email::text
  into v_email
  from auth.users u
  where u.id = new.id;

  if coalesce(v_email, '') like '%@firstvue.demo' then
    return new;
  end if;

  perform public.fv_maybe_purge_demo_pack();
  return new;
exception
  when others then
    -- Never block signup if purge fails.
    raise warning 'fv demo auto-purge skipped: %', sqlerrm;
    return new;
end;
$$;

drop trigger if exists trg_profiles_maybe_purge_demos on public.profiles;
create trigger trg_profiles_maybe_purge_demos
  after insert on public.profiles
  for each row
  execute function public.fv_trg_maybe_purge_demos_on_profile();

-- Public status for the auth screen. Credentials are the intentional demo pack
-- logins (same as docs/DEMO_SEED.md) and disappear once the pack is purged.
create or replace function public.fv_demo_accounts_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_available boolean;
  v_real int;
begin
  select exists (
    select 1
    from public.profiles
    where coalesce(is_demo, false) = true
       or username like 'fvdemo_%'
  )
  into v_available;

  v_real := public.fv_real_user_count();

  if not v_available then
    return jsonb_build_object(
      'available', false,
      'real_users', v_real,
      'threshold', 10
    );
  end if;

  return jsonb_build_object(
    'available', true,
    'email', 'fvdemo01@firstvue.demo',
    'username', 'fvdemo_maya',
    'password', 'FirstVueDemo!25',
    'real_users', v_real,
    'threshold', 10,
    'message',
      'Demo accounts are available while early access fills up. They are removed after 10 real signups.'
  );
end;
$$;

comment on function public.fv_demo_accounts_status() is
  'Returns whether seeded demo logins still exist (for auth UI).';

revoke all on function public.fv_demo_accounts_status() from public;
grant execute on function public.fv_demo_accounts_status() to anon, authenticated;

-- Run once on deploy in case the threshold is already met.
select public.fv_maybe_purge_demo_pack();

notify pgrst, 'reload schema';
