-- FirstVue shoutouts: creator → target entity shoutouts for homepage + profiles.

create table if not exists public.shoutouts (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null
    check (target_type in ('profile', 'business', 'professional', 'event', 'community')),
  target_id uuid not null,
  message text not null
    check (char_length(trim(message)) between 1 and 280),
  visibility text not null default 'public'
    check (visibility in ('public', 'followers')),
  status text not null default 'approved'
    check (status in ('approved', 'pending', 'removed')),
  created_at timestamptz not null default now()
);

create index if not exists shoutouts_created_at_idx
  on public.shoutouts (created_at desc)
  where status = 'approved';

create index if not exists shoutouts_target_idx
  on public.shoutouts (target_type, target_id, created_at desc)
  where status = 'approved';

create index if not exists shoutouts_creator_idx
  on public.shoutouts (creator_id, created_at desc);

alter table public.shoutouts enable row level security;

drop policy if exists "Public read approved shoutouts" on public.shoutouts;
create policy "Public read approved shoutouts"
  on public.shoutouts for select
  using (
    status = 'approved'
    and (
      visibility = 'public'
      or creator_id = auth.uid()
      or exists (
        select 1 from public.profile_follows pf
        where pf.following_id = creator_id
          and pf.follower_id = auth.uid()
      )
    )
  );

drop policy if exists "Users create shoutouts" on public.shoutouts;
create policy "Users create shoutouts"
  on public.shoutouts for insert to authenticated
  with check (
    creator_id = auth.uid()
    and status = 'approved'
  );

drop policy if exists "Users delete own shoutouts" on public.shoutouts;
create policy "Users delete own shoutouts"
  on public.shoutouts for delete to authenticated
  using (creator_id = auth.uid());
