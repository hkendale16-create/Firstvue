-- Allow feed comments on news posts and other non-media targets.
-- media_id was uuid -> business_media; app uses text keys like news-post:{uuid}.
--
-- We avoid ALTER COLUMN ... TYPE because Postgres blocks that while RLS policies
-- reference the column. Instead: add text column, copy, drop uuid column CASCADE
-- (drops dependent policies), rename, recreate policies.

alter table public.feed_comments
  drop constraint if exists feed_comments_media_id_fkey;

alter table public.feed_comments
  add column if not exists media_id_text text;

update public.feed_comments
set media_id_text = media_id::text
where media_id_text is null;

alter table public.feed_comments
  drop column if exists media_id cascade;

alter table public.feed_comments
  rename column media_id_text to media_id;

alter table public.feed_comments
  alter column media_id set not null;

create or replace function public.feed_comment_target_is_commentable(p_media_id text)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    case
      when p_media_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        exists (
          select 1
          from public.business_media m
          join public.businesses b on b.id = m.business_id
          where m.id::text = p_media_id
            and b.status = 'approved'
        )
      when p_media_id like 'news-post:%' then
        exists (
          select 1
          from public.community_news_posts p
          where p.id::text = split_part(p_media_id, ':', 2)
            and (
              p.status = 'approved'
              or p.author_id = auth.uid()
            )
        )
      when p_media_id like 'meet-owner:%' then
        exists (
          select 1
          from public.businesses b
          where b.id::text = split_part(p_media_id, ':', 2)
            and b.status = 'approved'
        )
      else false
    end;
$$;

drop policy if exists "Authenticated users read feed comments" on public.feed_comments;
drop policy if exists "Authenticated users post feed comments" on public.feed_comments;
drop policy if exists "Authors delete their feed comments" on public.feed_comments;

create policy "Authenticated users read feed comments"
  on public.feed_comments for select to authenticated
  using (public.feed_comment_target_is_commentable(media_id));

create policy "Authenticated users post feed comments"
  on public.feed_comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and public.feed_comment_target_is_commentable(media_id)
  );

create policy "Authors delete their feed comments"
  on public.feed_comments for delete to authenticated
  using (author_id = auth.uid());
