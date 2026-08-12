-- Allow authors to read their own news posts (any status) so freshly
-- created posts appear in the feed even before moderation defaults apply.

drop policy if exists "Authors read their news posts" on public.community_news_posts;
create policy "Authors read their news posts"
  on public.community_news_posts for select to authenticated
  using (author_id = auth.uid());
