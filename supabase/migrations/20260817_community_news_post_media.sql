-- Photos and videos on community news feed posts.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community-news-media',
  'community-news-media',
  false,
  52428800,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/bmp',
    'video/mp4', 'video/quicktime', 'video/webm', 'video/3gpp', 'video/x-msvideo',
    'video/x-matroska', 'video/x-m4v'
  ]
)
on conflict (id) do update
set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.community_news_post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_news_posts(id) on delete cascade,
  storage_path text not null unique,
  storage_provider text not null default 'supabase'
    check (storage_provider in ('supabase', 's3')),
  media_type text not null default 'image'
    check (media_type in ('image', 'video')),
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.community_news_post_media enable row level security;

drop policy if exists "Authors manage their news post media" on public.community_news_post_media;
create policy "Authors manage their news post media"
  on public.community_news_post_media for all to authenticated
  using (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.author_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.author_id = auth.uid()
    )
  );

drop policy if exists "Public reads approved news post media" on public.community_news_post_media;
create policy "Public reads approved news post media"
  on public.community_news_post_media for select
  using (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.status = 'approved'
    )
  );

drop policy if exists "Authors read their news post media" on public.community_news_post_media;
create policy "Authors read their news post media"
  on public.community_news_post_media for select to authenticated
  using (
    exists (
      select 1 from public.community_news_posts post
      where post.id = post_id and post.author_id = auth.uid()
    )
  );

drop policy if exists "Authors upload news post media" on storage.objects;
create policy "Authors upload news post media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'community-news-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Authors delete news post media files" on storage.objects;
create policy "Authors delete news post media files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'community-news-media'
    and owner_id = auth.uid()::text
  );

drop policy if exists "Public reads approved news post media files" on storage.objects;
create policy "Public reads approved news post media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'community-news-media'
    and exists (
      select 1
      from public.community_news_post_media media
      join public.community_news_posts post on post.id = media.post_id
      where media.storage_path = name and post.status = 'approved'
    )
  );

drop policy if exists "Authors view their news post media files" on storage.objects;
create policy "Authors view their news post media files"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'community-news-media'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1
        from public.community_news_post_media media
        join public.community_news_posts post on post.id = media.post_id
        where media.storage_path = name and post.author_id = auth.uid()
      )
    )
  );

create index if not exists community_news_post_media_post_idx
  on public.community_news_post_media (post_id, sort_order);
