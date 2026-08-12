-- Enforce community membership + posting_permission on community-bound news posts.
-- Users cannot post to a community merely by knowing its ID.

create or replace function public.can_post_to_community(target_community_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.communities c
    where c.id = target_community_id
      and (
        c.creator_id = auth.uid()
        or exists (
          select 1
          from public.community_members m
          where m.community_id = c.id
            and m.profile_id = auth.uid()
            and m.status = 'active'
            and (
              coalesce(c.posting_permission, 'members') = 'members'
              or (
                c.posting_permission = 'moderators'
                and m.role in ('owner', 'admin', 'moderator')
              )
              or (
                c.posting_permission = 'admins'
                and m.role in ('owner', 'admin')
              )
            )
        )
      )
  );
$$;

revoke all on function public.can_post_to_community(uuid) from public;
grant execute on function public.can_post_to_community(uuid) to authenticated;

drop policy if exists "Authenticated users post news" on public.community_news_posts;
create policy "Authenticated users post news"
  on public.community_news_posts for insert to authenticated
  with check (
    author_id = auth.uid()
    and (
      community_id is null
      or public.can_post_to_community(community_id)
    )
  );

-- Keep member_count roughly in sync on join/leave.
create or replace function public.sync_community_member_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.status = 'active' then
    update public.communities
      set member_count = greatest(member_count, 0) + 1,
          updated_at = now()
      where id = new.community_id;
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from 'active' and new.status = 'active' then
      update public.communities
        set member_count = greatest(member_count, 0) + 1,
            updated_at = now()
        where id = new.community_id;
    elsif old.status = 'active' and new.status is distinct from 'active' then
      update public.communities
        set member_count = greatest(member_count - 1, 0),
            updated_at = now()
        where id = new.community_id;
    end if;
  elsif tg_op = 'DELETE' and old.status = 'active' then
    update public.communities
      set member_count = greatest(member_count - 1, 0),
          updated_at = now()
      where id = old.community_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists community_members_count_trg on public.community_members;
create trigger community_members_count_trg
after insert or update or delete on public.community_members
for each row execute function public.sync_community_member_count();

create index if not exists community_news_posts_community_idx
  on public.community_news_posts (community_id, created_at desc)
  where community_id is not null;
