-- =============================================================================
-- Approval Center: atomic organizer application review + ensure table exists
-- Safe to re-run.
-- =============================================================================

create table if not exists public.community_organizer_applications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  display_name text not null,
  organization_name text,
  reason text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.community_organizer_applications enable row level security;

drop policy if exists "Users create organizer applications" on public.community_organizer_applications;
create policy "Users create organizer applications"
  on public.community_organizer_applications for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users read own organizer applications" on public.community_organizer_applications;
create policy "Users read own organizer applications"
  on public.community_organizer_applications for select to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Admins manage organizer applications" on public.community_organizer_applications;
create policy "Admins manage organizer applications"
  on public.community_organizer_applications for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

create index if not exists community_organizer_applications_status_idx
  on public.community_organizer_applications (status, created_at desc);

create table if not exists public.community_organizers (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  approved_at timestamptz not null default now()
);

alter table public.community_organizers enable row level security;

drop policy if exists "Authenticated read community organizers" on public.community_organizers;
create policy "Authenticated read community organizers"
  on public.community_organizers for select to authenticated
  using (true);

drop policy if exists "Admins manage community organizers" on public.community_organizers;
create policy "Admins manage community organizers"
  on public.community_organizers for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

create or replace function public.review_organizer_application(
  p_application_id uuid,
  p_approve boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not public.is_firstvue_admin() then
    raise exception 'Only FirstVue admins can review organizer applications';
  end if;

  select profile_id into v_profile
  from public.community_organizer_applications
  where id = p_application_id
  for update;

  if v_profile is null then
    raise exception 'Application not found';
  end if;

  update public.community_organizer_applications
  set status = case when p_approve then 'approved' else 'rejected' end
  where id = p_application_id;

  if p_approve then
    insert into public.community_organizers (profile_id, approved_at)
    values (v_profile, now())
    on conflict (profile_id) do update
      set approved_at = excluded.approved_at;
  end if;
end;
$$;

revoke all on function public.review_organizer_application(uuid, boolean) from public;
grant execute on function public.review_organizer_application(uuid, boolean) to authenticated;
