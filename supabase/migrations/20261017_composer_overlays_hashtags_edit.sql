-- =============================================================================
-- FirstVue — Story/Newsfeed composer upgrades
-- Overlays metadata, story links, text-only stories, post UPDATE RLS,
-- polymorphic content hashtags, hashtag usage events for velocity trending,
-- cached link previews.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Stories: richer metadata (structured overlays; optional media for text)
-- ---------------------------------------------------------------------------
alter table public.stories
  alter column media_path drop not null;

alter table public.stories
  drop constraint if exists stories_media_kind_check;

alter table public.stories
  add constraint stories_media_kind_check
  check (media_kind in ('image', 'video', 'text'));

alter table public.stories
  add column if not exists overlays jsonb not null default '[]'::jsonb;

alter table public.stories
  add column if not exists background_key text;

alter table public.stories
  add column if not exists link_url text;

alter table public.stories
  add column if not exists link_label text;

alter table public.stories
  add column if not exists link_kind text
    check (
      link_kind is null
      or link_kind in (
        'external', 'profile', 'post', 'business', 'community',
        'group', 'event', 'route'
      )
    );

-- Limited metadata edits after publish (not media/overlay structure rewrites).
drop policy if exists "Owners update own story metadata" on public.stories;
create policy "Owners update own story metadata"
  on public.stories for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2) Newsfeed posts: author UPDATE for caption/metadata edits
-- ---------------------------------------------------------------------------
drop policy if exists "Authors update their news posts" on public.community_news_posts;
create policy "Authors update their news posts"
  on public.community_news_posts for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

alter table public.community_news_posts
  add column if not exists location_label text;

alter table public.community_news_posts
  add column if not exists location_city text;

alter table public.community_news_posts
  add column if not exists location_state text;

alter table public.community_news_posts
  add column if not exists link_url text;

alter table public.community_news_posts
  add column if not exists link_label text;

-- ---------------------------------------------------------------------------
-- 3) Polymorphic content hashtags (global discovery beyond news posts)
-- ---------------------------------------------------------------------------
create table if not exists public.content_hashtags (
  id uuid primary key default gen_random_uuid(),
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  content_type text not null
    check (content_type in (
      'post', 'story', 'comment', 'event', 'vue', 'shoutout'
    )),
  content_id uuid not null,
  author_id uuid references public.profiles(id) on delete set null,
  city text,
  state text,
  created_at timestamptz not null default now(),
  unique (hashtag_id, content_type, content_id)
);

create index if not exists content_hashtags_hashtag_created_idx
  on public.content_hashtags (hashtag_id, created_at desc);

create index if not exists content_hashtags_type_created_idx
  on public.content_hashtags (content_type, created_at desc);

create index if not exists content_hashtags_geo_idx
  on public.content_hashtags (state, city, created_at desc)
  where city is not null or state is not null;

create index if not exists post_hashtags_hashtag_id_idx
  on public.post_hashtags (hashtag_id);

create index if not exists hashtags_use_count_idx
  on public.hashtags (use_count desc);

alter table public.content_hashtags enable row level security;

drop policy if exists "Anyone reads content hashtags" on public.content_hashtags;
create policy "Anyone reads content hashtags"
  on public.content_hashtags for select to anon, authenticated
  using (true);

drop policy if exists "Authors manage own content hashtags" on public.content_hashtags;
create policy "Authors manage own content hashtags"
  on public.content_hashtags for all to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4) Hashtag usage events — velocity / anti-spam for trending
-- ---------------------------------------------------------------------------
create table if not exists public.hashtag_usage_events (
  id bigserial primary key,
  hashtag_id uuid not null references public.hashtags(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  content_type text not null,
  content_id uuid not null,
  city text,
  state text,
  created_at timestamptz not null default now()
);

create index if not exists hashtag_usage_events_recent_idx
  on public.hashtag_usage_events (hashtag_id, created_at desc);

create index if not exists hashtag_usage_events_actor_recent_idx
  on public.hashtag_usage_events (actor_id, hashtag_id, created_at desc);

create index if not exists hashtag_usage_events_geo_recent_idx
  on public.hashtag_usage_events (state, city, created_at desc)
  where city is not null or state is not null;

alter table public.hashtag_usage_events enable row level security;

drop policy if exists "Anyone reads hashtag usage events" on public.hashtag_usage_events;
create policy "Anyone reads hashtag usage events"
  on public.hashtag_usage_events for select to anon, authenticated
  using (true);

-- Inserts only via SECURITY DEFINER sync helpers (no direct client insert).
revoke insert, update, delete on public.hashtag_usage_events from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Link preview cache (fetch once; reuse)
-- ---------------------------------------------------------------------------
create table if not exists public.link_previews (
  url_hash text primary key,
  url text not null,
  title text,
  description text,
  image_url text,
  site_name text,
  fetched_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days')
);

alter table public.link_previews enable row level security;

drop policy if exists "Anyone reads link previews" on public.link_previews;
create policy "Anyone reads link previews"
  on public.link_previews for select to anon, authenticated
  using (expires_at > now());

-- ---------------------------------------------------------------------------
-- 6) Sync helpers — posts (existing) + stories into content_hashtags
-- ---------------------------------------------------------------------------
create or replace function public.sync_content_hashtags(
  p_content_type text,
  p_content_id uuid,
  p_body text,
  p_author_id uuid default null,
  p_city text default null,
  p_state text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid := coalesce(p_author_id, v_uid);
  v_tag text;
  v_hashtag_id uuid;
  v_tags text[] := array[]::text[];
  v_match text;
  v_old_ids uuid[] := array[]::uuid[];
  v_new_ids uuid[] := array[]::uuid[];
  v_removed uuid[] := array[]::uuid[];
  v_insert_count integer;
  v_recent int;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if v_author is distinct from v_uid
     and not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;
  if p_content_type not in ('post', 'story', 'comment', 'event', 'vue', 'shoutout') then
    raise exception 'Invalid content type';
  end if;

  for v_match in
    select lower((m)[1])
    from regexp_matches(coalesce(p_body, ''), '#([A-Za-z0-9_]{2,30})', 'g') as m
  loop
    if not (v_match = any (v_tags)) and cardinality(v_tags) < 12 then
      v_tags := array_append(v_tags, v_match);
    end if;
  end loop;

  select coalesce(array_agg(hashtag_id), array[]::uuid[])
    into v_old_ids
  from public.content_hashtags
  where content_type = p_content_type
    and content_id = p_content_id;

  foreach v_tag in array v_tags
  loop
    insert into public.hashtags as h (tag, use_count)
    values (v_tag, 0)
    on conflict (tag) do update
      set tag = excluded.tag
    returning id into v_hashtag_id;

    v_new_ids := array_append(v_new_ids, v_hashtag_id);

    insert into public.content_hashtags (
      hashtag_id, content_type, content_id, author_id, city, state
    ) values (
      v_hashtag_id, p_content_type, p_content_id, v_author, p_city, p_state
    )
    on conflict (hashtag_id, content_type, content_id) do nothing;

    get diagnostics v_insert_count = row_count;
    if p_content_type <> 'post'
       and v_insert_count > 0
       and not (v_hashtag_id = any (v_old_ids)) then
      update public.hashtags
      set use_count = use_count + 1
      where id = v_hashtag_id;
    end if;

    -- Anti-spam: at most 3 usage events per actor/tag per hour.
    select count(*) into v_recent
    from public.hashtag_usage_events
    where actor_id = v_author
      and hashtag_id = v_hashtag_id
      and created_at > now() - interval '1 hour';

    if v_recent < 3 then
      insert into public.hashtag_usage_events (
        hashtag_id, actor_id, content_type, content_id, city, state
      ) values (
        v_hashtag_id, v_author, p_content_type, p_content_id, p_city, p_state
      );
    end if;
  end loop;

  with removed as (
    delete from public.content_hashtags ch
    where ch.content_type = p_content_type
      and ch.content_id = p_content_id
      and (
        cardinality(v_new_ids) = 0
        or not (ch.hashtag_id = any (v_new_ids))
      )
    returning ch.hashtag_id
  )
  select coalesce(array_agg(hashtag_id), array[]::uuid[])
    into v_removed
  from removed;

  if p_content_type <> 'post' and cardinality(v_removed) > 0 then
    update public.hashtags h
    set use_count = greatest(0, h.use_count - 1)
    where h.id = any (v_removed);
  end if;

  -- Keep legacy post_hashtags in sync for news posts (handles use_count).
  if p_content_type = 'post' then
    perform public.sync_post_hashtags(p_content_id, p_body);
  end if;
end;
$$;

revoke all on function public.sync_content_hashtags(text, uuid, text, uuid, text, text) from public;
grant execute on function public.sync_content_hashtags(text, uuid, text, uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7) Trending hashtags RPC (velocity + unique actors, not lifetime count alone)
-- ---------------------------------------------------------------------------
create or replace function public.fetch_trending_hashtags(
  p_hours int default 48,
  p_limit int default 20,
  p_city text default null,
  p_state text default null
)
returns table (
  tag text,
  score double precision,
  unique_actors bigint,
  recent_uses bigint,
  use_count int
)
language sql
stable
security definer
set search_path = public
as $$
  with windowed as (
    select
      e.hashtag_id,
      count(*)::bigint as recent_uses,
      count(distinct e.actor_id)::bigint as unique_actors,
      count(*) filter (
        where e.created_at > now() - make_interval(hours => greatest(p_hours / 4, 1))
      )::bigint as velocity_uses
    from public.hashtag_usage_events e
    where e.created_at > now() - make_interval(hours => greatest(p_hours, 1))
      and (p_state is null or e.state ilike p_state)
      and (p_city is null or e.city ilike p_city)
    group by e.hashtag_id
  )
  select
    h.tag::text,
    (
      (w.recent_uses * 1.0)
      + (w.unique_actors * 3.0)
      + (w.velocity_uses * 4.0)
      + ln(greatest(h.use_count, 1) + 1) * 0.25
    )::double precision as score,
    w.unique_actors,
    w.recent_uses,
    h.use_count
  from windowed w
  join public.hashtags h on h.id = w.hashtag_id
  where w.unique_actors >= 2  -- dampen single-account spam
  order by score desc
  limit greatest(p_limit, 1);
$$;

revoke all on function public.fetch_trending_hashtags(int, int, text, text) from public;
grant execute on function public.fetch_trending_hashtags(int, int, text, text) to anon, authenticated;
