-- Rental admin RLS hardening + message recipient search.
-- Safe to rerun.

-- Ensure rental moderation uses is_firstvue_admin() (JWT or profiles.account_type).
drop policy if exists "FirstVue admins manage rentals" on public.rentals;
create policy "FirstVue admins manage rentals"
  on public.rentals for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins manage rental media" on public.rental_media;
drop policy if exists "FirstVue admins manage rental media records" on public.rental_media;
create policy "FirstVue admins manage rental media"
  on public.rental_media for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "FirstVue admins read rental media files" on storage.objects;
drop policy if exists "FirstVue admins view rental media files" on storage.objects;
create policy "FirstVue admins read rental media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'rental-media'
    and public.is_firstvue_admin()
  );

-- Admins can read pending rentals for moderation queues.
drop policy if exists "FirstVue admins read pending rentals" on public.rentals;
create policy "FirstVue admins read pending rentals"
  on public.rentals for select to authenticated
  using (public.is_firstvue_admin() and status = 'pending');

-- Search members/business owners to start a direct message.
create or replace function public.search_message_recipients(search_query text)
returns table (
  profile_id uuid,
  display_name text,
  account_type text,
  business_id uuid,
  business_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select distinct on (p.id)
    p.id as profile_id,
    p.display_name,
    p.account_type,
    b.id as business_id,
    b.name as business_name
  from public.profiles p
  left join public.businesses b
    on b.created_by = p.id
   and b.status = 'approved'
  left join auth.users u on u.id = p.id
  where auth.uid() is not null
    and p.id <> auth.uid()
    and p.display_name is not null
    and char_length(trim(search_query)) >= 2
    and (
      p.display_name ilike '%' || trim(search_query) || '%'
      or u.email ilike '%' || trim(search_query) || '%'
    )
  order by p.id, b.created_at desc nulls last
  limit 25;
$$;

revoke all on function public.search_message_recipients(text) from public;
grant execute on function public.search_message_recipients(text) to authenticated;
