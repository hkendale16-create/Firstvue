-- =============================================================================
-- FirstVue Early Access: Founding Members, Feedback, Ideas, Product Analytics
-- Lightweight prototype systems. Demo accounts excluded from legitimate metrics.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Profile recognition (Founding Member / FirstVue Builder)
-- ---------------------------------------------------------------------------

create table if not exists public.profile_recognition_badges (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  badge_key text not null check (
    badge_key in ('founding_member', 'firstvue_builder')
  ),
  market_label text not null default 'Atlanta',
  year_label integer not null default 2026,
  cohort_key text not null default 'early_access_2026',
  awarded_at timestamptz not null default now(),
  awarded_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  unique (profile_id, badge_key)
);

create index if not exists profile_recognition_badges_active_idx
  on public.profile_recognition_badges (badge_key, profile_id)
  where revoked_at is null;

alter table public.profile_recognition_badges enable row level security;

drop policy if exists "Public reads active recognition badges" on public.profile_recognition_badges;
create policy "Public reads active recognition badges"
  on public.profile_recognition_badges for select to anon, authenticated
  using (
    revoked_at is null
    and exists (
      select 1 from public.profiles p
      where p.id = profile_id
        and coalesce(p.is_demo, false) = false
    )
  );

drop policy if exists "Admins manage recognition badges" on public.profile_recognition_badges;
create policy "Admins manage recognition badges"
  on public.profile_recognition_badges for all to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

create or replace function public.fv_grant_recognition_badge(
  p_profile_id uuid,
  p_badge_key text,
  p_market_label text default 'Atlanta',
  p_year_label integer default 2026,
  p_cohort_key text default 'early_access_2026'
)
returns public.profile_recognition_badges
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.profile_recognition_badges;
begin
  if v_uid is null or not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;
  if exists (
    select 1 from public.profiles p
    where p.id = p_profile_id and coalesce(p.is_demo, false) = true
  ) then
    raise exception 'Demo accounts cannot receive recognition badges';
  end if;
  if p_badge_key not in ('founding_member', 'firstvue_builder') then
    raise exception 'Invalid badge';
  end if;

  insert into public.profile_recognition_badges (
    profile_id, badge_key, market_label, year_label, cohort_key, awarded_by, revoked_at
  ) values (
    p_profile_id, p_badge_key,
    coalesce(nullif(trim(p_market_label), ''), 'Atlanta'),
    coalesce(p_year_label, 2026),
    coalesce(nullif(trim(p_cohort_key), ''), 'early_access_2026'),
    v_uid, null
  )
  on conflict (profile_id, badge_key) do update
    set market_label = excluded.market_label,
        year_label = excluded.year_label,
        cohort_key = excluded.cohort_key,
        awarded_at = now(),
        awarded_by = v_uid,
        revoked_at = null
  returning * into v_row;

  insert into public.activity_notifications (user_id, type, title, body, payload)
  values (
    p_profile_id,
    'recognition_badge_awarded',
    case when p_badge_key = 'founding_member'
      then 'You’re a Founding Member'
      else 'FirstVue Builder'
    end,
    'Thank you for helping build FirstVue.',
    jsonb_build_object('badge_key', p_badge_key, 'market', v_row.market_label, 'year', v_row.year_label)
  );

  return v_row;
end;
$$;

revoke all on function public.fv_grant_recognition_badge(uuid, text, text, integer, text) from public;
grant execute on function public.fv_grant_recognition_badge(uuid, text, text, integer, text) to authenticated;

create or replace function public.fv_revoke_recognition_badge(
  p_profile_id uuid,
  p_badge_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;
  update public.profile_recognition_badges
  set revoked_at = now()
  where profile_id = p_profile_id
    and badge_key = p_badge_key
    and revoked_at is null;
end;
$$;

revoke all on function public.fv_revoke_recognition_badge(uuid, text) from public;
grant execute on function public.fv_revoke_recognition_badge(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Feedback submissions
-- ---------------------------------------------------------------------------

create table if not exists public.early_access_feedback (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (
    category in (
      'suggest_idea',
      'report_problem',
      'what_i_like',
      'whats_confusing',
      'what_should_be_near_me',
      'anything_else'
    )
  ),
  title text,
  body text not null check (char_length(trim(body)) >= 3),
  related_feature text,
  city_preference text,
  near_me_kind text check (
    near_me_kind is null or near_me_kind in (
      'business', 'event', 'venue', 'restaurant', 'bar', 'nightlife',
      'food', 'activity', 'popup', 'entrepreneur', 'other'
    )
  ),
  near_me_name text,
  near_me_neighborhood text,
  near_me_why text,
  expected_behavior text,
  actual_behavior text,
  screenshot_path text,
  app_version text,
  build_number text,
  platform text,
  device_type text,
  current_screen text,
  status text not null default 'new' check (
    status in ('new', 'reviewed', 'archived')
  ),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists early_access_feedback_created_idx
  on public.early_access_feedback (created_at desc);
create index if not exists early_access_feedback_category_idx
  on public.early_access_feedback (category, created_at desc);
create index if not exists early_access_feedback_profile_idx
  on public.early_access_feedback (profile_id, created_at desc);

alter table public.early_access_feedback enable row level security;

drop policy if exists "Users insert own feedback" on public.early_access_feedback;
create policy "Users insert own feedback"
  on public.early_access_feedback for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users read own feedback" on public.early_access_feedback;
create policy "Users read own feedback"
  on public.early_access_feedback for select to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin());

drop policy if exists "Users update own open feedback" on public.early_access_feedback;
create policy "Users update own open feedback"
  on public.early_access_feedback for update to authenticated
  using (profile_id = auth.uid() and status = 'new')
  with check (profile_id = auth.uid());

drop policy if exists "Admins update feedback" on public.early_access_feedback;
create policy "Admins update feedback"
  on public.early_access_feedback for update to authenticated
  using (public.is_firstvue_admin())
  with check (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- Feature ideas + votes
-- ---------------------------------------------------------------------------

create table if not exists public.feature_ideas (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) >= 3),
  body text not null check (char_length(trim(body)) >= 3),
  moderation_status text not null default 'pending' check (
    moderation_status in ('pending', 'approved', 'rejected')
  ),
  roadmap_status text not null default 'submitted' check (
    roadmap_status in (
      'submitted', 'considering', 'planned', 'building', 'released', 'not_planned'
    )
  ),
  vote_count integer not null default 0 check (vote_count >= 0),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.feature_idea_votes (
  idea_id uuid not null references public.feature_ideas(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (idea_id, profile_id)
);

create index if not exists feature_ideas_public_idx
  on public.feature_ideas (moderation_status, vote_count desc, created_at desc);
create index if not exists feature_ideas_profile_idx
  on public.feature_ideas (profile_id, created_at desc);
create index if not exists feature_idea_votes_profile_idx
  on public.feature_idea_votes (profile_id, created_at desc);

alter table public.feature_ideas enable row level security;
alter table public.feature_idea_votes enable row level security;

drop policy if exists "Public reads approved ideas" on public.feature_ideas;
create policy "Public reads approved ideas"
  on public.feature_ideas for select to anon, authenticated
  using (
    moderation_status = 'approved'
    or profile_id = auth.uid()
    or public.is_firstvue_admin()
  );

drop policy if exists "Users submit ideas" on public.feature_ideas;
create policy "Users submit ideas"
  on public.feature_ideas for insert to authenticated
  with check (
    profile_id = auth.uid()
    and moderation_status = 'pending'
    and roadmap_status = 'submitted'
    and vote_count = 0
  );

drop policy if exists "Users update own pending ideas" on public.feature_ideas;
create policy "Users update own pending ideas"
  on public.feature_ideas for update to authenticated
  using (
    (profile_id = auth.uid() and moderation_status = 'pending')
    or public.is_firstvue_admin()
  )
  with check (
    (profile_id = auth.uid() and moderation_status = 'pending')
    or public.is_firstvue_admin()
  );

-- Prevent non-admins from changing moderation/roadmap/vote_count via trigger.
create or replace function public.fv_protect_feature_idea_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_firstvue_admin() or current_user in ('postgres', 'supabase_admin')
     or auth.role() = 'service_role' then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.moderation_status is distinct from old.moderation_status
      or new.roadmap_status is distinct from old.roadmap_status
      or new.vote_count is distinct from old.vote_count
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at then
      raise exception 'Idea status is admin-controlled';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_feature_idea_fields on public.feature_ideas;
create trigger trg_protect_feature_idea_fields
  before update on public.feature_ideas
  for each row execute function public.fv_protect_feature_idea_fields();

drop policy if exists "Users read own votes" on public.feature_idea_votes;
create policy "Users read own votes"
  on public.feature_idea_votes for select to authenticated
  using (
    profile_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.feature_ideas i
      where i.id = idea_id and i.moderation_status = 'approved'
    )
  );

drop policy if exists "Users vote once" on public.feature_idea_votes;
create policy "Users vote once"
  on public.feature_idea_votes for insert to authenticated
  with check (
    profile_id = auth.uid()
    and exists (
      select 1 from public.feature_ideas i
      where i.id = idea_id and i.moderation_status = 'approved'
    )
  );

drop policy if exists "Users remove own vote" on public.feature_idea_votes;
create policy "Users remove own vote"
  on public.feature_idea_votes for delete to authenticated
  using (profile_id = auth.uid());

create or replace function public.fv_toggle_feature_idea_vote(p_idea_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_exists boolean;
  v_count integer;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  if not exists (
    select 1 from public.feature_ideas
    where id = p_idea_id and moderation_status = 'approved'
  ) then
    raise exception 'Idea not available';
  end if;

  select exists (
    select 1 from public.feature_idea_votes
    where idea_id = p_idea_id and profile_id = v_uid
  ) into v_exists;

  if v_exists then
    delete from public.feature_idea_votes
    where idea_id = p_idea_id and profile_id = v_uid;
  else
    insert into public.feature_idea_votes (idea_id, profile_id)
    values (p_idea_id, v_uid);
  end if;

  select count(*)::int into v_count
  from public.feature_idea_votes where idea_id = p_idea_id;

  update public.feature_ideas
  set vote_count = v_count, updated_at = now()
  where id = p_idea_id;

  return jsonb_build_object(
    'voted', not v_exists,
    'vote_count', v_count
  );
end;
$$;

revoke all on function public.fv_toggle_feature_idea_vote(uuid) from public;
grant execute on function public.fv_toggle_feature_idea_vote(uuid) to authenticated;

create or replace function public.fv_moderate_feature_idea(
  p_idea_id uuid,
  p_moderation_status text,
  p_roadmap_status text default null
)
returns public.feature_ideas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.feature_ideas;
begin
  if auth.uid() is null or not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;
  if p_moderation_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Invalid moderation status';
  end if;

  update public.feature_ideas
  set moderation_status = p_moderation_status,
      roadmap_status = coalesce(p_roadmap_status, roadmap_status),
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  where id = p_idea_id
  returning * into v_row;

  if v_row.id is null then raise exception 'Idea not found'; end if;
  return v_row;
end;
$$;

revoke all on function public.fv_moderate_feature_idea(uuid, text, text) from public;
grant execute on function public.fv_moderate_feature_idea(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- First-party product events (lightweight; no sensitive payloads)
-- ---------------------------------------------------------------------------

create table if not exists public.product_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete set null,
  event_name text not null,
  screen text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint product_events_name_ok check (
    event_name in (
      'account_created',
      'onboarding_completed',
      'vue_viewed',
      'vue_completed',
      'vue_liked',
      'vue_commented',
      'vue_shared',
      'vue_saved',
      'event_viewed',
      'event_saved',
      'event_interested',
      'event_shared',
      'event_chat_opened',
      'business_viewed',
      'business_followed',
      'profile_viewed',
      'user_followed',
      'search_performed',
      'group_viewed',
      'community_viewed',
      'message_started',
      'feedback_opened',
      'feedback_submitted',
      'idea_submitted',
      'idea_voted',
      'early_access_prompt_shown',
      'early_access_prompt_dismissed',
      'pmf_survey_answered'
    )
  )
);

create index if not exists product_events_name_created_idx
  on public.product_events (event_name, created_at desc);
create index if not exists product_events_profile_created_idx
  on public.product_events (profile_id, created_at desc)
  where profile_id is not null;

alter table public.product_events enable row level security;

drop policy if exists "Users insert own product events" on public.product_events;
create policy "Users insert own product events"
  on public.product_events for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Admins read product events" on public.product_events;
create policy "Admins read product events"
  on public.product_events for select to authenticated
  using (public.is_firstvue_admin() or profile_id = auth.uid());

-- Block sensitive keys in metadata
create or replace function public.fv_sanitize_product_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.metadata ? 'password'
     or new.metadata ? 'access_token'
     or new.metadata ? 'refresh_token'
     or new.metadata ? 'token'
     or new.metadata ? 'message_body'
     or new.metadata ? 'private_message' then
    raise exception 'Sensitive fields are not allowed in product analytics';
  end if;
  -- Drop search query text if present (privacy).
  new.metadata := new.metadata - 'query' - 'search_query' - 'message';
  return new;
end;
$$;

drop trigger if exists trg_sanitize_product_event on public.product_events;
create trigger trg_sanitize_product_event
  before insert on public.product_events
  for each row execute function public.fv_sanitize_product_event();

-- ---------------------------------------------------------------------------
-- PMF survey + feedback prompt cooldowns
-- ---------------------------------------------------------------------------

create table if not exists public.product_survey_responses (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  survey_key text not null check (survey_key in ('pmf_disappear')),
  response_key text not null check (
    response_key in ('very_disappointed', 'somewhat_disappointed', 'not_disappointed')
  ),
  created_at timestamptz not null default now(),
  unique (profile_id, survey_key)
);

alter table public.product_survey_responses enable row level security;

drop policy if exists "Users manage own survey responses" on public.product_survey_responses;
create policy "Users manage own survey responses"
  on public.product_survey_responses for all to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin())
  with check (profile_id = auth.uid());

create table if not exists public.early_access_prompt_state (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  dismiss_count integer not null default 0,
  last_dismissed_at timestamptz,
  last_shown_at timestamptz,
  feedback_opened_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.early_access_prompt_state enable row level security;

drop policy if exists "Users manage own prompt state" on public.early_access_prompt_state;
create policy "Users manage own prompt state"
  on public.early_access_prompt_state for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Feedback media bucket (private)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'early-access-feedback',
  'early-access-feedback',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

drop policy if exists "EA users upload feedback media" on storage.objects;
create policy "EA users upload feedback media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'early-access-feedback'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "EA users read feedback media" on storage.objects;
create policy "EA users read feedback media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'early-access-feedback'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_firstvue_admin()
    )
  );

-- ---------------------------------------------------------------------------
-- Admin Early Access overview
-- ---------------------------------------------------------------------------

create or replace function public.fv_early_access_admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_now timestamptz := now();
begin
  if auth.uid() is null or not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;

  return jsonb_build_object(
    'users_total', (
      select count(*)::int from public.profiles where coalesce(is_demo, false) = false
    ),
    'users_new_7d', (
      select count(*)::int from public.profiles
      where coalesce(is_demo, false) = false
        and created_at >= v_now - interval '7 days'
    ),
    'founding_members', (
      select count(*)::int from public.profile_recognition_badges b
      join public.profiles p on p.id = b.profile_id
      where b.badge_key = 'founding_member'
        and b.revoked_at is null
        and coalesce(p.is_demo, false) = false
    ),
    'dau', (
      select count(distinct profile_id)::int from public.product_events e
      join public.profiles p on p.id = e.profile_id
      where e.created_at >= date_trunc('day', v_now)
        and coalesce(p.is_demo, false) = false
    ),
    'wau', (
      select count(distinct profile_id)::int from public.product_events e
      join public.profiles p on p.id = e.profile_id
      where e.created_at >= v_now - interval '7 days'
        and coalesce(p.is_demo, false) = false
    ),
    'feedback_total', (select count(*)::int from public.early_access_feedback),
    'feedback_bugs', (
      select count(*)::int from public.early_access_feedback where category = 'report_problem'
    ),
    'ideas_submitted', (select count(*)::int from public.feature_ideas),
    'ideas_pending', (
      select count(*)::int from public.feature_ideas where moderation_status = 'pending'
    ),
    'top_ideas', (
      select coalesce(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
      from (
        select id, title, vote_count, roadmap_status
        from public.feature_ideas
        where moderation_status = 'approved'
        order by vote_count desc, created_at desc
        limit 10
      ) t
    ),
    'feedback_by_category', (
      select coalesce(jsonb_object_agg(category, cnt), '{}'::jsonb)
      from (
        select category, count(*)::int as cnt
        from public.early_access_feedback
        group by category
      ) s
    ),
    'events_by_name_7d', (
      select coalesce(jsonb_object_agg(event_name, cnt), '{}'::jsonb)
      from (
        select e.event_name, count(*)::int as cnt
        from public.product_events e
        left join public.profiles p on p.id = e.profile_id
        where e.created_at >= v_now - interval '7 days'
          and coalesce(p.is_demo, false) = false
        group by e.event_name
      ) s
    )
  );
end;
$$;

revoke all on function public.fv_early_access_admin_overview() from public;
grant execute on function public.fv_early_access_admin_overview() to authenticated;

comment on table public.profile_recognition_badges is
  'Admin-assigned Early Access recognition (Founding Member, FirstVue Builder). Not purchasable.';
comment on table public.early_access_feedback is
  'User feedback from Help Build FirstVue. No sensitive tokens/logs.';
comment on table public.feature_ideas is
  'Community feature ideas with admin moderation and roadmap status.';
comment on table public.product_events is
  'First-party product analytics. Demo users excluded from admin aggregates.';
