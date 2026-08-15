-- =============================================================================
-- FirstVue prototype readiness hardening (2026-08-15)
--
-- 1) Hashtag sync RPC (authors can index captions; use_count maintained)
-- 2) Multi-reaction type on community_news_post_sparks
-- 3) Disable under-13 / parental self-claim for messaging
-- 4) Tighten profile-media storage SELECT
-- 5) Enforce messaging blocks + rate limits on send
-- 6) record_feed_interaction presence (safe recreate)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Hashtags: public read + author sync RPC
-- ---------------------------------------------------------------------------
drop policy if exists "Authenticated read hashtags" on public.hashtags;
drop policy if exists "Public read hashtags" on public.hashtags;
create policy "Public read hashtags"
  on public.hashtags for select to anon, authenticated
  using (true);

drop policy if exists "Authenticated read post hashtags" on public.post_hashtags;
drop policy if exists "Public read post hashtags" on public.post_hashtags;
create policy "Public read post hashtags"
  on public.post_hashtags for select to anon, authenticated
  using (true);

drop policy if exists "Authors manage post hashtags" on public.post_hashtags;
drop policy if exists "Authors insert post hashtags" on public.post_hashtags;
drop policy if exists "Authors delete post hashtags" on public.post_hashtags;

create policy "Authors insert post hashtags"
  on public.post_hashtags for insert to authenticated
  with check (
    exists (
      select 1 from public.community_news_posts p
      where p.id = post_id and p.author_id = auth.uid()
    )
  );

create policy "Authors delete post hashtags"
  on public.post_hashtags for delete to authenticated
  using (
    exists (
      select 1 from public.community_news_posts p
      where p.id = post_id and p.author_id = auth.uid()
    )
  );

create or replace function public.sync_post_hashtags(
  p_post_id uuid,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_author uuid;
  v_tag text;
  v_hashtag_id uuid;
  v_tags text[] := array[]::text[];
  v_match text;
  v_old_ids uuid[] := array[]::uuid[];
  v_new_ids uuid[] := array[]::uuid[];
  v_removed uuid[] := array[]::uuid[];
  v_insert_count integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select author_id into v_author
  from public.community_news_posts
  where id = p_post_id;

  if v_author is null then
    raise exception 'Post not found';
  end if;

  if v_author <> v_uid and not public.is_firstvue_admin() then
    raise exception 'Not authorized to sync hashtags for this post';
  end if;

  -- Cap at 12 unique tags to limit ranking abuse.
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
  from public.post_hashtags
  where post_id = p_post_id;

  foreach v_tag in array v_tags
  loop
    insert into public.hashtags as h (tag, use_count)
    values (v_tag, 0)
    on conflict (tag) do update
      set tag = excluded.tag
    returning id into v_hashtag_id;

    v_new_ids := array_append(v_new_ids, v_hashtag_id);

    insert into public.post_hashtags (post_id, hashtag_id)
    values (p_post_id, v_hashtag_id)
    on conflict do nothing;

    get diagnostics v_insert_count = row_count;
    if v_insert_count > 0 and not (v_hashtag_id = any (v_old_ids)) then
      update public.hashtags
      set use_count = use_count + 1
      where id = v_hashtag_id;
    end if;
  end loop;

  with removed as (
    delete from public.post_hashtags ph
    where ph.post_id = p_post_id
      and (
        cardinality(v_new_ids) = 0
        or not (ph.hashtag_id = any (v_new_ids))
      )
    returning ph.hashtag_id
  )
  select coalesce(array_agg(hashtag_id), array[]::uuid[])
    into v_removed
  from removed;

  if cardinality(v_removed) > 0 then
    update public.hashtags h
    set use_count = greatest(0, h.use_count - 1)
    where h.id = any (v_removed);
  end if;
end;
$$;

revoke all on function public.sync_post_hashtags(uuid, text) from public;
grant execute on function public.sync_post_hashtags(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Multi-reactions (Spark default + extended types)
-- ---------------------------------------------------------------------------
alter table public.community_news_post_sparks
  add column if not exists reaction_type text not null default 'spark';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'community_news_post_sparks_reaction_type_check'
  ) then
    alter table public.community_news_post_sparks
      add constraint community_news_post_sparks_reaction_type_check
      check (
        reaction_type in (
          'spark', 'love', 'excited', 'laugh', 'wow', 'celebrate'
        )
      );
  end if;
end $$;

create or replace function public.set_post_reaction(
  p_post_id uuid,
  p_reaction_type text default 'spark'
)
returns table (reaction_type text, spark_count bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_type text := lower(coalesce(nullif(trim(p_reaction_type), ''), 'spark'));
  v_existing text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if v_type not in ('spark', 'love', 'excited', 'laugh', 'wow', 'celebrate') then
    raise exception 'Invalid reaction type';
  end if;

  select s.reaction_type into v_existing
  from public.community_news_post_sparks s
  where s.post_id = p_post_id and s.user_id = v_uid;

  if v_existing is null then
    insert into public.community_news_post_sparks (post_id, user_id, reaction_type)
    values (p_post_id, v_uid, v_type);
  elsif v_existing = v_type then
    delete from public.community_news_post_sparks
    where post_id = p_post_id and user_id = v_uid;
  else
    update public.community_news_post_sparks
    set reaction_type = v_type
    where post_id = p_post_id and user_id = v_uid;
  end if;

  return query
  select
    (
      select s.reaction_type
      from public.community_news_post_sparks s
      where s.post_id = p_post_id and s.user_id = v_uid
    ) as reaction_type,
    (
      select count(*)::bigint
      from public.community_news_post_sparks s
      where s.post_id = p_post_id
    ) as spark_count;
end;
$$;

revoke all on function public.set_post_reaction(uuid, text) from public;
grant execute on function public.set_post_reaction(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) Under-13 / parental: disabled for prototype (13+ only product)
-- ---------------------------------------------------------------------------
create or replace function public.fv_msg_is_under_13(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select false;
$$;

drop policy if exists "Parents manage parental rows" on public.fv_msg_parental;
drop policy if exists "Parents read parental rows" on public.fv_msg_parental;
drop policy if exists "No client parental writes" on public.fv_msg_parental;
drop policy if exists "No client parental updates" on public.fv_msg_parental;
drop policy if exists "No client parental deletes" on public.fv_msg_parental;

-- Read own parental rows only (legacy); no client inserts/updates/deletes.
create policy "Parents read parental rows"
  on public.fv_msg_parental for select to authenticated
  using (parent_id = auth.uid() or child_id = auth.uid());

-- Explicit deny for writes from authenticated clients (service role still can).
create policy "No client parental writes"
  on public.fv_msg_parental for insert to authenticated
  with check (false);

create policy "No client parental updates"
  on public.fv_msg_parental for update to authenticated
  using (false);

create policy "No client parental deletes"
  on public.fv_msg_parental for delete to authenticated
  using (false);

-- ---------------------------------------------------------------------------
-- 4) profile-media storage: only linked public media / own folder / live stories
-- ---------------------------------------------------------------------------
drop policy if exists "Public read profile media files" on storage.objects;
drop policy if exists "Authenticated users read profile media files" on storage.objects;
drop policy if exists "Scoped read profile media files" on storage.objects;

create policy "Scoped read profile media files"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'profile-media'
    and (
      (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)
      or exists (
        select 1
        from public.profile_media media
        where media.storage_path = name
      )
      or exists (
        select 1
        from public.stories story
        where story.media_path = name
          and story.expires_at > now()
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 5) Messaging: block + rate-limit on member message insert
-- ---------------------------------------------------------------------------
create or replace function public.fv_msg_enforce_send_guards()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_peer uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if not public.fv_msg_within_rate_limit('message', 40, 60) then
    raise exception 'Message rate limit exceeded';
  end if;

  -- Direct conversations: reject if either participant blocked the other.
  select m.profile_id into v_peer
  from public.fv_msg_members m
  join public.fv_msg_conversations c on c.id = m.conversation_id
  where m.conversation_id = new.conversation_id
    and m.profile_id is distinct from v_uid
    and c.kind = 'direct'
  limit 1;

  if v_peer is not null
     and not public.fv_msg_contact_allowed(v_uid, v_peer) then
    raise exception 'Messaging is blocked between these accounts';
  end if;

  return new;
end;
$$;

drop trigger if exists fv_msg_enforce_send_guards_trg on public.fv_msg_messages;
create trigger fv_msg_enforce_send_guards_trg
  before insert on public.fv_msg_messages
  for each row
  execute function public.fv_msg_enforce_send_guards();

-- ---------------------------------------------------------------------------
-- 6) Ensure record_feed_interaction exists (idempotent stub if table present)
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.feed_interactions') is not null
     and not exists (
       select 1 from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = 'record_feed_interaction'
     ) then
    execute $fn$
      create function public.record_feed_interaction(
        p_post_id uuid,
        p_interaction_type text,
        p_source_tab text default 'main',
        p_watch_time_ms integer default 0,
        p_completion_percent numeric default null,
        p_session_id text default null
      )
      returns uuid
      language plpgsql
      security definer
      set search_path = public
      as $body$
      declare
        v_uid uuid := auth.uid();
        v_id uuid;
      begin
        if v_uid is null then
          raise exception 'Not authenticated';
        end if;
        insert into public.feed_interactions (
          user_id, post_id, interaction_type, source_tab,
          watch_time_ms, completion_percent, session_id
        ) values (
          v_uid, p_post_id, p_interaction_type, coalesce(p_source_tab, 'main'),
          coalesce(p_watch_time_ms, 0), p_completion_percent, p_session_id
        )
        returning id into v_id;
        return v_id;
      exception when others then
        return null;
      end;
      $body$;
    $fn$;
    execute 'grant execute on function public.record_feed_interaction(uuid, text, text, integer, numeric, text) to authenticated';
  end if;
end $$;

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- 7) Event Planner: draft/cancelled statuses + organizer RLS
-- ---------------------------------------------------------------------------
alter table public.community_events
  drop constraint if exists community_events_status_check;

alter table public.community_events
  add constraint community_events_status_check
  check (
    status in (
      'pending',
      'approved',
      'rejected',
      'cancelled',
      'draft'
    )
  );

drop policy if exists "Authenticated read approved events" on public.community_events;
drop policy if exists "Public reads approved events" on public.community_events;

create policy "Authenticated read approved events"
  on public.community_events for select to authenticated
  using (status = 'approved' or organizer_id = auth.uid());

create policy "Public reads approved events"
  on public.community_events for select to anon
  using (status = 'approved');

drop policy if exists "Authors manage their events" on public.community_events;
create policy "Authors manage their events"
  on public.community_events for update to authenticated
  using (organizer_id = auth.uid())
  with check (organizer_id = auth.uid());

create index if not exists community_events_organizer_idx
  on public.community_events (organizer_id, created_at desc);
