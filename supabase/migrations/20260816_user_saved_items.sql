-- User saved items (news posts and other content for profile / saved tab)

create table if not exists public.user_saved_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content_type text not null check (content_type in ('news_post', 'business')),
  content_id text not null,
  created_at timestamptz not null default now(),
  unique (user_id, content_type, content_id)
);

alter table public.user_saved_items enable row level security;

drop policy if exists "Users read own saved items" on public.user_saved_items;
create policy "Users read own saved items"
  on public.user_saved_items for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users save items" on public.user_saved_items;
create policy "Users save items"
  on public.user_saved_items for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users unsave items" on public.user_saved_items;
create policy "Users unsave items"
  on public.user_saved_items for delete to authenticated
  using (user_id = auth.uid());

create index if not exists user_saved_items_user_created_idx
  on public.user_saved_items (user_id, created_at desc);
