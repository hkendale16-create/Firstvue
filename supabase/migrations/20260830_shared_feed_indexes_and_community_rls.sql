-- Shared FirstVue feed support indexes/policies for community_news_posts.
-- Does NOT recreate the posts table. Existing posts remain intact.

-- Community/Group scoped feed filters by community_id.
create index if not exists community_news_posts_community_idx
  on public.community_news_posts (community_id, created_at desc)
  where community_id is not null;

-- Author timeline index for personal profile feeds.
create index if not exists community_news_posts_author_idx
  on public.community_news_posts (author_id, created_at desc);

-- Members can read community-visibility posts for communities they belong to.
-- Public + followers policies already exist; this fills the community case.
drop policy if exists "Members read community-only news posts" on public.community_news_posts;
create policy "Members read community-only news posts"
  on public.community_news_posts for select to authenticated
  using (
    status = 'approved'
    and visibility = 'community'
    and community_id is not null
    and (
      author_id = auth.uid()
      or exists (
        select 1
        from public.community_members cm
        where cm.community_id = community_news_posts.community_id
          and cm.profile_id = auth.uid()
          and cm.status = 'active'
      )
    )
  );
