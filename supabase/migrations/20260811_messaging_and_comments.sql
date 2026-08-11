-- Direct messaging and Vue feed comments.
-- Run in Supabase SQL Editor after prior migrations.

create table if not exists public.direct_message_threads (
  id uuid primary key default gen_random_uuid(),
  participant_a uuid not null references public.profiles(id) on delete cascade,
  participant_b uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  check (participant_a <> participant_b)
);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.direct_message_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null references public.business_media(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);

alter table public.direct_message_threads enable row level security;
alter table public.direct_messages enable row level security;
alter table public.feed_comments enable row level security;

drop policy if exists "Participants read their message threads" on public.direct_message_threads;
drop policy if exists "Participants create message threads" on public.direct_message_threads;
drop policy if exists "Participants update their message threads" on public.direct_message_threads;
drop policy if exists "Participants read messages in their threads" on public.direct_messages;
drop policy if exists "Participants send messages in their threads" on public.direct_messages;
drop policy if exists "Authenticated users read feed comments" on public.feed_comments;
drop policy if exists "Authenticated users post feed comments" on public.feed_comments;
drop policy if exists "Authors delete their feed comments" on public.feed_comments;

create policy "Participants read their message threads"
  on public.direct_message_threads for select to authenticated
  using (participant_a = auth.uid() or participant_b = auth.uid());

create policy "Participants create message threads"
  on public.direct_message_threads for insert to authenticated
  with check (participant_a = auth.uid() or participant_b = auth.uid());

create policy "Participants update their message threads"
  on public.direct_message_threads for update to authenticated
  using (participant_a = auth.uid() or participant_b = auth.uid());

create policy "Participants read messages in their threads"
  on public.direct_messages for select to authenticated
  using (
    exists (
      select 1 from public.direct_message_threads t
      where t.id = thread_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  );

create policy "Participants send messages in their threads"
  on public.direct_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.direct_message_threads t
      where t.id = thread_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  );

create policy "Authenticated users read feed comments"
  on public.feed_comments for select to authenticated
  using (
    exists (
      select 1
      from public.business_media m
      join public.businesses b on b.id = m.business_id
      where m.id = media_id and b.status = 'approved'
    )
  );

create policy "Authenticated users post feed comments"
  on public.feed_comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1
      from public.business_media m
      join public.businesses b on b.id = m.business_id
      where m.id = media_id and b.status = 'approved'
    )
  );

create policy "Authors delete their feed comments"
  on public.feed_comments for delete to authenticated
  using (author_id = auth.uid());

create index if not exists direct_message_threads_participants_idx
  on public.direct_message_threads (participant_a, participant_b, last_message_at desc);
create index if not exists direct_messages_thread_idx
  on public.direct_messages (thread_id, created_at);
create index if not exists feed_comments_media_idx
  on public.feed_comments (media_id, created_at desc);

create unique index if not exists direct_message_threads_pair_idx
  on public.direct_message_threads (participant_a, participant_b);
