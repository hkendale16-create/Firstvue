-- Enable Supabase Realtime for community news feed and comments.
-- Safe to re-run: skips tables already in supabase_realtime publication.

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'community_news_posts'
  ) then
    alter publication supabase_realtime add table public.community_news_posts;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'feed_comments'
  ) then
    alter publication supabase_realtime add table public.feed_comments;
  end if;
end $$;
