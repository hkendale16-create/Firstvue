-- Menus, specials, and community news feed

create table if not exists public.business_menu_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text,
  price_label text,
  category text not null default 'Menu',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.business_specials (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  title text not null,
  description text,
  price_label text,
  valid_until timestamptz,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.community_news_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  body text not null,
  status text not null default 'approved'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create table if not exists public.community_news_post_sparks (
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

alter table public.business_menu_items enable row level security;
alter table public.business_specials enable row level security;
alter table public.community_news_posts enable row level security;
alter table public.community_news_post_sparks enable row level security;

drop policy if exists "Public reads menu items" on public.business_menu_items;
create policy "Public reads menu items"
  on public.business_menu_items for select
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_menu_items.business_id and b.status = 'approved'
    )
  );

drop policy if exists "Owners manage menu items" on public.business_menu_items;
create policy "Owners manage menu items"
  on public.business_menu_items for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_menu_items.business_id and b.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_menu_items.business_id and b.created_by = auth.uid()
    )
  );

drop policy if exists "Public reads specials" on public.business_specials;
create policy "Public reads specials"
  on public.business_specials for select
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_specials.business_id and b.status = 'approved'
    )
  );

drop policy if exists "Owners manage specials" on public.business_specials;
create policy "Owners manage specials"
  on public.business_specials for all to authenticated
  using (
    exists (
      select 1 from public.businesses b
      where b.id = business_specials.business_id and b.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.businesses b
      where b.id = business_specials.business_id and b.created_by = auth.uid()
    )
  );

drop policy if exists "Public reads approved news posts" on public.community_news_posts;
create policy "Public reads approved news posts"
  on public.community_news_posts for select
  using (status = 'approved');

drop policy if exists "Authenticated users post news" on public.community_news_posts;
create policy "Authenticated users post news"
  on public.community_news_posts for insert to authenticated
  with check (author_id = auth.uid());

drop policy if exists "Authors delete their news posts" on public.community_news_posts;
create policy "Authors delete their news posts"
  on public.community_news_posts for delete to authenticated
  using (author_id = auth.uid());

drop policy if exists "Authenticated users spark news posts" on public.community_news_post_sparks;
create policy "Authenticated users spark news posts"
  on public.community_news_post_sparks for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Authenticated users read news sparks" on public.community_news_post_sparks;
create policy "Authenticated users read news sparks"
  on public.community_news_post_sparks for select to authenticated
  using (true);

create index if not exists business_menu_items_business_idx
  on public.business_menu_items (business_id, sort_order);

create index if not exists business_specials_business_idx
  on public.business_specials (business_id, sort_order);

create index if not exists community_news_posts_created_idx
  on public.community_news_posts (created_at desc);
