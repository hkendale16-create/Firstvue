-- =============================================================================
-- FIRSTVUE: Social Platform Upgrade (Phases 1-7) — ALL-IN-ONE BACKEND
-- =============================================================================
-- Run in Supabase Dashboard > SQL Editor AFTER prior FirstVue migrations.
--
-- Prerequisites (if not already applied):
--   supabase/migrations/20260810_initial_firstvue_schema.sql
--   supabase/apply_pending_migrations.sql
--
-- This file adds:
--   • Usernames, bio, location, privacy on profiles
--   • user_preferences (location, notifications, floating bubble)
--   • profile_follows + follow_requests (private accounts)
--   • post_reposts, hashtags, post_mentions
--   • communities, community_members, community_follows
--   • community_events, event_follows, event_attendance
--   • notification_subscriptions, post visibility
--   • live_stream_eligibility (architecture only)
--   • Realtime publication for profile_follows + communities
--
-- Safe to re-run (IF NOT EXISTS / DROP POLICY IF EXISTS).
-- =============================================================================

-- FirstVue social platform upgrade (Phases 1-7)
-- Run after prior migrations. Safe to re-run (IF NOT EXISTS / DROP POLICY IF EXISTS).

create extension if not exists citext;

-- ---------------------------------------------------------------------------
-- Profile extensions: username, bio, location, privacy
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists username citext,
  add column if not exists bio text,
  add column if not exists website text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists postal_code text,
  add column if not exists country_code text default 'US',
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists is_private boolean not null default false,
  add column if not exists profile_visibility text not null default 'public'
    check (profile_visibility in ('public', 'followers', 'private'));

create unique index if not exists profiles_username_unique_idx
  on public.profiles (username)
  where username is not null;

create index if not exists profiles_username_search_idx
  on public.profiles (username);

create index if not exists profiles_display_name_search_idx
  on public.profiles (display_name);

-- ---------------------------------------------------------------------------
-- User preferences (location, notifications, UI)
-- ---------------------------------------------------------------------------
create table if not exists public.user_preferences (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  preferred_city text,
  preferred_state text,
  preferred_postal_code text,
  preferred_latitude double precision,
  preferred_longitude double precision,
  use_device_location boolean not null default true,
  push_messages boolean not null default true,
  push_follows boolean not null default true,
  push_comments boolean not null default true,
  push_community boolean not null default true,
  show_floating_messages boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

drop policy if exists "Users manage own preferences" on public.user_preferences;
create policy "Users manage own preferences"
  on public.user_preferences for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Profile follows (personal/professional/business owner profiles)
-- ---------------------------------------------------------------------------
create table if not exists public.profile_follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

alter table public.profile_follows enable row level security;

drop policy if exists "Authenticated read profile follows" on public.profile_follows;
create policy "Authenticated read profile follows"
  on public.profile_follows for select to authenticated
  using (true);

drop policy if exists "Users manage own follows" on public.profile_follows;
create policy "Users manage own follows"
  on public.profile_follows for insert to authenticated
  with check (follower_id = auth.uid());

drop policy if exists "Users unfollow" on public.profile_follows;
create policy "Users unfollow"
  on public.profile_follows for delete to authenticated
  using (follower_id = auth.uid());

create index if not exists profile_follows_following_idx
  on public.profile_follows (following_id, created_at desc);

create index if not exists profile_follows_follower_idx
  on public.profile_follows (follower_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Follow requests (private profiles)
-- ---------------------------------------------------------------------------
create table if not exists public.follow_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, target_id),
  check (requester_id <> target_id)
);

alter table public.follow_requests enable row level security;

drop policy if exists "Participants read follow requests" on public.follow_requests;
create policy "Participants read follow requests"
  on public.follow_requests for select to authenticated
  using (requester_id = auth.uid() or target_id = auth.uid());

drop policy if exists "Users create follow requests" on public.follow_requests;
create policy "Users create follow requests"
  on public.follow_requests for insert to authenticated
  with check (requester_id = auth.uid());

drop policy if exists "Targets respond to follow requests" on public.follow_requests;
create policy "Targets respond to follow requests"
  on public.follow_requests for update to authenticated
  using (target_id = auth.uid())
  with check (target_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Notification subscriptions (separate from follow)
-- ---------------------------------------------------------------------------
create table if not exists public.notification_subscriptions (
  id uuid primary key default gen_random_uuid(),
  subscriber_id uuid not null references public.profiles(id) on delete cascade,
  target_profile_id uuid references public.profiles(id) on delete cascade,
  target_community_id uuid,
  level text not null default 'all'
    check (level in ('all', 'important', 'events', 'mentions', 'off')),
  created_at timestamptz not null default now(),
  unique (subscriber_id, target_profile_id),
  check (target_profile_id is not null or target_community_id is not null)
);

alter table public.notification_subscriptions enable row level security;

drop policy if exists "Users manage notification subscriptions" on public.notification_subscriptions;
create policy "Users manage notification subscriptions"
  on public.notification_subscriptions for all to authenticated
  using (subscriber_id = auth.uid())
  with check (subscriber_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Reposts (reference original post, no media duplication)
-- ---------------------------------------------------------------------------
create table if not exists public.post_reposts (
  id uuid primary key default gen_random_uuid(),
  original_post_id uuid not null references public.community_news_posts(id) on delete cascade,
  reposter_id uuid not null references public.profiles(id) on delete cascade,
  reposter_identity_type text not null default 'personal'
    check (reposter_identity_type in ('personal', 'business', 'professional', 'community')),
  reposter_business_id uuid references public.businesses(id) on delete set null,
  reposter_community_id uuid,
  comment text,
  created_at timestamptz not null default now(),
  unique (original_post_id, reposter_id, reposter_identity_type, reposter_business_id, reposter_community_id)
);

alter table public.post_reposts enable row level security;

drop policy if exists "Authenticated read reposts" on public.post_reposts;
create policy "Authenticated read reposts"
  on public.post_reposts for select to authenticated
  using (true);

drop policy if exists "Users create reposts" on public.post_reposts;
create policy "Users create reposts"
  on public.post_reposts for insert to authenticated
  with check (reposter_id = auth.uid());

drop policy if exists "Users delete own reposts" on public.post_reposts;
create policy "Users delete own reposts"
  on public.post_reposts for delete to authenticated
  using (reposter_id = auth.uid());

create index if not exists post_reposts_original_idx
  on public.post_reposts (original_post_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Hashtags & mentions
-- ---------------------------------------------------------------------------
create table if not exists public.hashtags (
  id uuid primary key default gen_random_uuid(),
  tag citext not null unique,
  use_count integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.post_hashtags (
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  primary key (post_id, hashtag_id)
);

create table if not exists public.post_mentions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  mentioned_profile_id uuid references public.profiles(id) on delete cascade,
  mentioned_business_id uuid references public.businesses(id) on delete cascade,
  mention_text text not null,
  created_at timestamptz not null default now()
);

alter table public.hashtags enable row level security;
alter table public.post_hashtags enable row level security;
alter table public.post_mentions enable row level security;

drop policy if exists "Authenticated read hashtags" on public.hashtags;
create policy "Authenticated read hashtags"
  on public.hashtags for select to authenticated using (true);

drop policy if exists "Authenticated read post hashtags" on public.post_hashtags;
create policy "Authenticated read post hashtags"
  on public.post_hashtags for select to authenticated using (true);

drop policy if exists "Authors manage post hashtags" on public.post_hashtags;
create policy "Authors manage post hashtags"
  on public.post_hashtags for insert to authenticated
  with check (
    exists (
      select 1 from public.community_news_posts p
      where p.id = post_id and p.author_id = auth.uid()
    )
  );

drop policy if exists "Authenticated read mentions" on public.post_mentions;
create policy "Authenticated read mentions"
  on public.post_mentions for select to authenticated using (true);

drop policy if exists "Authors manage mentions" on public.post_mentions;
create policy "Authors manage mentions"
  on public.post_mentions for insert to authenticated
  with check (
    exists (
      select 1 from public.community_news_posts p
      where p.id = post_id and p.author_id = auth.uid()
    )
  );

create index if not exists hashtags_tag_idx on public.hashtags (tag);

-- ---------------------------------------------------------------------------
-- Community groups
-- ---------------------------------------------------------------------------
create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text,
  description text,
  category text,
  image_url text,
  cover_url text,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  city text,
  state text,
  postal_code text,
  country_code text default 'US',
  latitude double precision,
  longitude double precision,
  radius_miles double precision,
  privacy_type text not null default 'public'
    check (privacy_type in ('public', 'private', 'hidden')),
  posting_permission text not null default 'members'
    check (posting_permission in ('members', 'moderators', 'admins')),
  rules text,
  member_count integer not null default 0,
  follower_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists communities_slug_unique_idx
  on public.communities (slug)
  where slug is not null;

create index if not exists communities_location_idx
  on public.communities (state, city);

create index if not exists communities_category_idx
  on public.communities (category);

create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'moderator', 'member')),
  status text not null default 'active'
    check (status in ('active', 'pending', 'banned')),
  joined_at timestamptz not null default now(),
  primary key (community_id, profile_id)
);

create table if not exists public.community_follows (
  community_id uuid not null references public.communities(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (community_id, profile_id)
);

create table if not exists public.community_tags (
  community_id uuid not null references public.communities(id) on delete cascade,
  tag text not null,
  primary key (community_id, tag)
);

alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.community_follows enable row level security;
alter table public.community_tags enable row level security;

drop policy if exists "Authenticated read public communities" on public.communities;
create policy "Authenticated read public communities"
  on public.communities for select to authenticated
  using (privacy_type in ('public', 'private') or creator_id = auth.uid());

drop policy if exists "Users create communities" on public.communities;
create policy "Users create communities"
  on public.communities for insert to authenticated
  with check (creator_id = auth.uid());

drop policy if exists "Admins update communities" on public.communities;
create policy "Admins update communities"
  on public.communities for update to authenticated
  using (
    creator_id = auth.uid()
    or exists (
      select 1 from public.community_members m
      where m.community_id = id
        and m.profile_id = auth.uid()
        and m.role in ('owner', 'admin')
        and m.status = 'active'
    )
  );

drop policy if exists "Authenticated read community members" on public.community_members;
create policy "Authenticated read community members"
  on public.community_members for select to authenticated using (true);

drop policy if exists "Users join communities" on public.community_members;
create policy "Users join communities"
  on public.community_members for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users leave communities" on public.community_members;
create policy "Users leave communities"
  on public.community_members for delete to authenticated
  using (profile_id = auth.uid());

drop policy if exists "Authenticated read community follows" on public.community_follows;
create policy "Authenticated read community follows"
  on public.community_follows for select to authenticated using (true);

drop policy if exists "Users follow communities" on public.community_follows;
create policy "Users follow communities"
  on public.community_follows for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- Link notification_subscriptions.community FK after communities exist
do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'notification_subscriptions_target_community_id_fkey'
  ) then
    alter table public.notification_subscriptions
      add constraint notification_subscriptions_target_community_id_fkey
      foreign key (target_community_id) references public.communities(id) on delete cascade;
  end if;
exception when others then null;
end $$;

do $$
begin
  if not exists (
    select 1 from information_schema.table_constraints
    where constraint_name = 'post_reposts_reposter_community_id_fkey'
  ) then
    alter table public.post_reposts
      add constraint post_reposts_reposter_community_id_fkey
      foreign key (reposter_community_id) references public.communities(id) on delete set null;
  end if;
exception when others then null;
end $$;

-- ---------------------------------------------------------------------------
-- Event follow & attendance
-- ---------------------------------------------------------------------------
create table if not exists public.community_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  community_id uuid references public.communities(id) on delete set null,
  organizer_id uuid not null references public.profiles(id) on delete cascade,
  city text,
  state text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  status text not null default 'approved'
    check (status in ('pending', 'approved', 'cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.event_follows (
  event_id uuid not null references public.community_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

create table if not exists public.event_attendance (
  event_id uuid not null references public.community_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'attending'
    check (status in ('attending', 'not_attending', 'interested')),
  created_at timestamptz not null default now(),
  primary key (event_id, profile_id)
);

alter table public.community_events enable row level security;
alter table public.event_follows enable row level security;
alter table public.event_attendance enable row level security;

drop policy if exists "Authenticated read approved events" on public.community_events;
create policy "Authenticated read approved events"
  on public.community_events for select to authenticated
  using (status = 'approved' or organizer_id = auth.uid());

drop policy if exists "Organizers create events" on public.community_events;
create policy "Organizers create events"
  on public.community_events for insert to authenticated
  with check (organizer_id = auth.uid());

drop policy if exists "Authenticated read event follows" on public.event_follows;
create policy "Authenticated read event follows"
  on public.event_follows for select to authenticated using (true);

drop policy if exists "Users manage event follows" on public.event_follows;
create policy "Users manage event follows"
  on public.event_follows for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Authenticated read attendance" on public.event_attendance;
create policy "Authenticated read attendance"
  on public.event_attendance for select to authenticated using (true);

drop policy if exists "Users manage attendance" on public.event_attendance;
create policy "Users manage attendance"
  on public.event_attendance for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Post privacy column
-- ---------------------------------------------------------------------------
alter table public.community_news_posts
  add column if not exists visibility text not null default 'public'
    check (visibility in ('public', 'followers', 'community', 'private'));

alter table public.community_news_posts
  add column if not exists community_id uuid references public.communities(id) on delete set null;

-- ---------------------------------------------------------------------------
-- Username helpers
-- ---------------------------------------------------------------------------
create or replace function public.normalize_username(raw text)
returns text
language sql
immutable
as $$
  select lower(trim(raw));
$$;

create or replace function public.is_username_available(candidate text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1
    from public.profiles p
    where p.username = public.normalize_username(candidate)
      and (auth.uid() is null or p.id <> auth.uid())
  );
$$;

revoke all on function public.is_username_available(text) from public;
grant execute on function public.is_username_available(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Live stream eligibility (architecture only — no streaming backend)
-- ---------------------------------------------------------------------------
create table if not exists public.live_stream_eligibility (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  is_verified boolean not null default false,
  follower_count integer not null default 0,
  is_eligible boolean not null default false,
  checked_at timestamptz not null default now()
);

alter table public.live_stream_eligibility enable row level security;

drop policy if exists "Users read own live eligibility" on public.live_stream_eligibility;
create policy "Users read own live eligibility"
  on public.live_stream_eligibility for select to authenticated
  using (profile_id = auth.uid());

create or replace function public.refresh_live_eligibility(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_followers integer;
  v_verified boolean;
begin
  select count(*)::integer into v_followers
  from public.profile_follows
  where following_id = p_profile_id;

  select (verification_status = 'verified') into v_verified
  from public.businesses b
  where b.created_by = p_profile_id
  limit 1;

  insert into public.live_stream_eligibility (profile_id, is_verified, follower_count, is_eligible, checked_at)
  values (
    p_profile_id,
    coalesce(v_verified, false),
    v_followers,
    coalesce(v_verified, false) and v_followers >= 20,
    now()
  )
  on conflict (profile_id) do update set
    is_verified = excluded.is_verified,
    follower_count = excluded.follower_count,
    is_eligible = excluded.is_eligible,
    checked_at = excluded.checked_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- Realtime (optional — extend publication)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and tablename = 'profile_follows'
    ) then
      alter publication supabase_realtime add table public.profile_follows;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and tablename = 'communities'
    ) then
      alter publication supabase_realtime add table public.communities;
    end if;
  end if;
exception when others then null;
end $$;
