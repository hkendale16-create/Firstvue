-- Paste entire file into Supabase SQL Editor and Run.
-- Account deletion blockers + personal data cleanup RPC (safe to re-run).
-- Mirrors supabase/migrations/20260924_account_deletion.sql

create or replace function public.get_account_deletion_blockers(p_user_id uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := coalesce(p_user_id, auth.uid());
  v_businesses jsonb := '[]'::jsonb;
  v_hubs jsonb := '[]'::jsonb;
  v_rentals jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required'
      using errcode = '28000';
  end if;

  if auth.uid() is not null and auth.uid() <> v_uid and not public.is_firstvue_admin() then
    raise exception 'Not authorized'
      using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name) order by b.name), '[]'::jsonb)
    into v_businesses
  from (
    select distinct b.id, b.name
    from public.businesses b
    where b.created_by = v_uid
    union
    select distinct b.id, b.name
    from public.businesses b
    join public.business_memberships m on m.business_id = b.id
    where m.profile_id = v_uid
      and m.role = 'owner'
  ) b;

  select coalesce(jsonb_agg(jsonb_build_object('id', h.id, 'name', h.name) order by h.name), '[]'::jsonb)
    into v_hubs
  from public.community_hubs h
  where h.created_by_profile_id = v_uid
     or (
       exists (
         select 1
         from public.community_hub_roles r
         where r.hub_id = h.id
           and r.profile_id = v_uid
           and r.status = 'active'
           and r.role in ('creator', 'lead_leader', 'leader', 'admin', 'moderator')
       )
       and not exists (
         select 1
         from public.community_hub_roles r2
         where r2.hub_id = h.id
           and r2.profile_id <> v_uid
           and r2.status = 'active'
           and r2.role in ('creator', 'lead_leader', 'leader', 'admin', 'moderator')
       )
     );

  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'title', r.title) order by r.title), '[]'::jsonb)
    into v_rentals
  from public.rentals r
  where r.owner_id = v_uid
    and r.status in ('pending', 'approved');

  return jsonb_build_object(
    'blocked',
      jsonb_array_length(v_businesses) > 0
      or jsonb_array_length(v_hubs) > 0
      or jsonb_array_length(v_rentals) > 0,
    'businesses', v_businesses,
    'community_hubs', v_hubs,
    'rental_listings', v_rentals,
    'message',
      case
        when jsonb_array_length(v_businesses) > 0
          or jsonb_array_length(v_hubs) > 0
          or jsonb_array_length(v_rentals) > 0
        then 'Transfer or delete your businesses, communities, and rental listings first.'
        else null
      end
  );
end;
$$;

comment on function public.get_account_deletion_blockers(uuid) is
  'Returns owned entities that must be removed before account deletion.';

revoke all on function public.get_account_deletion_blockers(uuid) from public;
grant execute on function public.get_account_deletion_blockers(uuid) to authenticated;
grant execute on function public.get_account_deletion_blockers(uuid) to service_role;

create or replace function public.delete_my_account_data(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_blockers jsonb;
begin
  if p_user_id is null then
    raise exception 'User id is required'
      using errcode = '22023';
  end if;

  select public.get_account_deletion_blockers(p_user_id) into v_blockers;
  if coalesce((v_blockers->>'blocked')::boolean, false) then
    raise exception '%', coalesce(v_blockers->>'message', 'Account deletion blocked.')
      using errcode = 'P0001',
            detail = v_blockers::text;
  end if;

  delete from public.community_news_posts
  where author_id = p_user_id
    and business_id is null
    and professional_profile_id is null
    and coalesce(author_profile_type, 'user') = 'user';

  update public.fv_msg_messages
  set deleted_for_everyone_at = coalesce(deleted_for_everyone_at, now()),
      metadata = coalesce(metadata, '{}'::jsonb) || '{"deleted_account": true}'::jsonb
  where sender_id = p_user_id;

  begin
    update public.direct_messages
    set body = '[Message from deleted account]'
    where sender_id = p_user_id;
  exception
    when undefined_table then null;
    when undefined_column then null;
  end;

  delete from public.profile_media where profile_id = p_user_id;

  begin
    delete from public.user_saved_items where user_id = p_user_id;
  exception
    when undefined_table then null;
  end;

  update public.profiles
  set display_name = 'Deleted user',
      username = null,
      bio = null,
      website = null,
      city = null,
      state = null,
      postal_code = null,
      country_code = 'US',
      latitude = null,
      longitude = null,
      phone = null,
      birthday = null,
      address_line_1 = null,
      address_line_2 = null,
      formatted_address = null,
      place_id = null,
      is_private = true,
      profile_visibility = 'private',
      show_email_on_profile = false,
      field_visibility = '{}'::jsonb,
      hide_read_receipts = true,
      updated_at = now()
  where id = p_user_id;
end;
$$;

comment on function public.delete_my_account_data(uuid) is
  'Removes personal data for account deletion. Does not delete auth.users — call from Edge Function.';

revoke all on function public.delete_my_account_data(uuid) from public;
grant execute on function public.delete_my_account_data(uuid) to service_role;
