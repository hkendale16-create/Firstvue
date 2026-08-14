-- =============================================================================
-- FirstVue — community hub follows + entity-only publish destination
-- =============================================================================

create table if not exists public.community_hub_follows (
  hub_id uuid not null references public.community_hubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (hub_id, profile_id)
);

create index if not exists community_hub_follows_profile_idx
  on public.community_hub_follows (profile_id, created_at desc);

alter table public.community_hub_follows enable row level security;

drop policy if exists "Anyone reads hub follows" on public.community_hub_follows;
create policy "Anyone reads hub follows"
  on public.community_hub_follows for select
  to anon, authenticated
  using (true);

drop policy if exists "Users follow hubs" on public.community_hub_follows;
create policy "Users follow hubs"
  on public.community_hub_follows for insert
  to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users unfollow hubs" on public.community_hub_follows;
create policy "Users unfollow hubs"
  on public.community_hub_follows for delete
  to authenticated
  using (profile_id = auth.uid());

create or replace function public.sync_community_hub_follower_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_hubs
    set follower_count = coalesce(follower_count, 0) + 1
    where id = new.hub_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.community_hubs
    set follower_count = greatest(coalesce(follower_count, 0) - 1, 0)
    where id = old.hub_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_sync_community_hub_follower_count
  on public.community_hub_follows;
create trigger trg_sync_community_hub_follower_count
  after insert or delete on public.community_hub_follows
  for each row execute function public.sync_community_hub_follower_count();

-- Allow entity-isolated posts that stay off Home/Explore until Share to Feed.
do $$
begin
  alter table public.community_news_posts
    drop constraint if exists community_news_posts_publish_destination_check;
exception
  when undefined_table then null;
  when undefined_object then null;
end $$;

alter table public.community_news_posts
  drop constraint if exists community_news_posts_publish_destination_check;

alter table public.community_news_posts
  add constraint community_news_posts_publish_destination_check
  check (publish_destination in ('feed', 'vue', 'feed_and_vue', 'entity_only'));
