-- Posts scoped to professional profiles and community events.

alter table public.community_news_posts
  add column if not exists professional_profile_id uuid
    references public.professional_profiles(id) on delete set null;

alter table public.community_news_posts
  add column if not exists event_id uuid
    references public.community_events(id) on delete set null;

create index if not exists community_news_posts_business_idx
  on public.community_news_posts (business_id, created_at desc)
  where business_id is not null;

create index if not exists community_news_posts_professional_idx
  on public.community_news_posts (professional_profile_id, created_at desc)
  where professional_profile_id is not null;

create index if not exists community_news_posts_event_idx
  on public.community_news_posts (event_id, created_at desc)
  where event_id is not null;
