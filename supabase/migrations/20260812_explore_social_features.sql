-- Explore, social, events, and notification features

alter table public.businesses
  add column if not exists coming_soon boolean not null default false;

alter table public.businesses
  add column if not exists coming_soon_note text;

create table if not exists public.business_social_links (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  platform text not null,
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.community_organizers (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  approved_at timestamptz not null default now()
);

create table if not exists public.community_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete set null,
  organizer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  event_at timestamptz,
  location_label text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

alter table public.feed_comments
  add column if not exists parent_id uuid references public.feed_comments(id) on delete cascade;

create table if not exists public.feed_comment_sparks (
  comment_id uuid not null references public.feed_comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create table if not exists public.activity_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.business_social_links enable row level security;
alter table public.community_organizers enable row level security;
alter table public.community_events enable row level security;
alter table public.feed_comment_sparks enable row level security;
alter table public.activity_notifications enable row level security;

drop policy if exists "Owners manage business social links" on public.business_social_links;
create policy "Owners manage business social links"
  on public.business_social_links for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_social_links.business_id
        and b.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_social_links.business_id
        and b.created_by = auth.uid()
    )
  );

drop policy if exists "Public reads business social links" on public.business_social_links;
create policy "Public reads business social links"
  on public.business_social_links for select
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_social_links.business_id
        and b.status = 'approved'
    )
  );

drop policy if exists "Public reads approved organizers" on public.community_organizers;
create policy "Public reads approved organizers"
  on public.community_organizers for select
  using (true);

drop policy if exists "Admins manage organizers" on public.community_organizers;
create policy "Admins manage organizers"
  on public.community_organizers for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

drop policy if exists "Public reads approved events" on public.community_events;
create policy "Public reads approved events"
  on public.community_events for select
  using (status = 'approved');

drop policy if exists "Organizers and owners post events" on public.community_events;
create policy "Organizers and owners post events"
  on public.community_events for insert to authenticated
  with check (
    organizer_id = auth.uid()
    and (
      exists (select 1 from public.community_organizers where profile_id = auth.uid())
      or exists (
        select 1 from public.businesses b
        where b.created_by = auth.uid() and b.status = 'approved'
      )
    )
  );

drop policy if exists "Authors manage their events" on public.community_events;
create policy "Authors manage their events"
  on public.community_events for update to authenticated
  using (organizer_id = auth.uid())
  with check (organizer_id = auth.uid());

drop policy if exists "Users read their activity notifications" on public.activity_notifications;
create policy "Users read their activity notifications"
  on public.activity_notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users update their activity notifications" on public.activity_notifications;
create policy "Users update their activity notifications"
  on public.activity_notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Authenticated users spark comments" on public.feed_comment_sparks;
create policy "Authenticated users spark comments"
  on public.feed_comment_sparks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Authenticated users read comment sparks" on public.feed_comment_sparks;
create policy "Authenticated users read comment sparks"
  on public.feed_comment_sparks for select to authenticated
  using (true);

create index if not exists business_social_links_business_idx
  on public.business_social_links (business_id, sort_order);

create index if not exists community_events_status_idx
  on public.community_events (status, event_at desc);

create index if not exists activity_notifications_user_idx
  on public.activity_notifications (user_id, created_at desc);

create index if not exists feed_comments_parent_idx
  on public.feed_comments (parent_id, created_at asc);
