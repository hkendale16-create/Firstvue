-- FIRSTVUE professional social links, selected social posts, and catalogs.
-- Social content is stored as user-provided links; no platform content is scraped.

create table if not exists public.professional_social_links (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  platform text not null
    check (platform in ('instagram', 'tiktok', 'youtube', 'facebook', 'website', 'other')),
  label text not null default '' check (char_length(label) <= 80),
  url text not null check (char_length(url) between 8 and 500),
  source text not null default 'link' check (source in ('link', 'connected')),
  connected_external_id text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.professional_social_posts (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  platform text not null
    check (platform in ('instagram', 'tiktok', 'youtube', 'facebook', 'other')),
  post_url text not null check (char_length(post_url) between 8 and 500),
  caption text not null default '' check (char_length(caption) <= 500),
  source text not null default 'link' check (source in ('link', 'connected')),
  connected_external_id text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.professional_catalog_items (
  id uuid primary key default gen_random_uuid(),
  professional_profile_id uuid not null
    references public.professional_profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text not null default '' check (char_length(description) <= 1000),
  price_label text not null default '' check (char_length(price_label) <= 60),
  image_url text not null default '' check (char_length(image_url) <= 500),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.professional_social_links enable row level security;
alter table public.professional_social_posts enable row level security;
alter table public.professional_catalog_items enable row level security;

drop policy if exists "Professionals manage their social links" on public.professional_social_links;
drop policy if exists "Public reads approved professional social links" on public.professional_social_links;
drop policy if exists "Professionals manage their linked social posts" on public.professional_social_posts;
drop policy if exists "Public reads approved professional social posts" on public.professional_social_posts;
drop policy if exists "Professionals manage their catalog" on public.professional_catalog_items;
drop policy if exists "Public reads approved professional catalog" on public.professional_catalog_items;

create policy "Professionals manage their social links"
  on public.professional_social_links for all to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  )
  with check (
    source = 'link'
    and exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  );

create policy "Public reads approved professional social links"
  on public.professional_social_links for select
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create policy "Professionals manage their linked social posts"
  on public.professional_social_posts for all to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  )
  with check (
    source = 'link'
    and exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  );

create policy "Public reads approved professional social posts"
  on public.professional_social_posts for select
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create policy "Professionals manage their catalog"
  on public.professional_catalog_items for all to authenticated
  using (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.profile_id = auth.uid()
    )
  );

create policy "Public reads approved professional catalog"
  on public.professional_catalog_items for select
  using (
    is_active
    and exists (
      select 1 from public.professional_profiles professional
      where professional.id = professional_profile_id
        and professional.status = 'approved'
    )
  );

create index if not exists professional_social_links_profile_idx
  on public.professional_social_links (professional_profile_id, sort_order);
create index if not exists professional_social_posts_profile_idx
  on public.professional_social_posts (professional_profile_id, sort_order);
create index if not exists professional_catalog_profile_idx
  on public.professional_catalog_items (professional_profile_id, is_active, sort_order);

-- A future official OAuth connection must run server-side (for example through
-- a Supabase Edge Function) and store tokens outside client-readable tables.
-- That trusted backend may write source='connected' and connected_external_id.
