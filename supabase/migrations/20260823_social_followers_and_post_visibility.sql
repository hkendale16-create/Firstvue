-- Follower list profile reads + followers-only post visibility
-- Safe to re-run.

-- Let signed-in users read basic profile fields for members visible in social graph.
drop policy if exists "Authenticated read member profile summaries" on public.profiles;
create policy "Authenticated read member profile summaries"
  on public.profiles for select to authenticated
  using (display_name is not null or id = auth.uid());

-- Scope public feed reads to public visibility only.
drop policy if exists "Public reads approved news posts" on public.community_news_posts;
create policy "Public reads approved news posts"
  on public.community_news_posts for select
  using (
    status = 'approved'
    and coalesce(visibility, 'public') = 'public'
  );

-- Followers (and authors) can read followers-only approved posts.
drop policy if exists "Followers read followers-only news posts" on public.community_news_posts;
create policy "Followers read followers-only news posts"
  on public.community_news_posts for select to authenticated
  using (
    status = 'approved'
    and coalesce(visibility, 'public') = 'followers'
    and (
      author_id = auth.uid()
      or exists (
        select 1
        from public.profile_follows pf
        where pf.follower_id = auth.uid()
          and pf.following_id = community_news_posts.author_id
      )
    )
  );
