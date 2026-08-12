-- Allow anyone to read news post spark rows so counts display without sign-in.

drop policy if exists "Public reads news spark counts" on public.community_news_post_sparks;
create policy "Public reads news spark counts"
  on public.community_news_post_sparks for select
  using (true);
