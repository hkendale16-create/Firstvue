-- =============================================================================
-- FirstVue — permanent Story cleanup after 24h
--
-- Client-side filtering alone is insufficient. This migration:
-- 1) Adds a secure cleanup function that deletes expired story rows.
-- 2) Deletes dedicated story storage objects only when the path is not reused
--    by permanent profile/media/post references.
-- 3) Schedules cleanup via pg_cron when available (otherwise call via Edge
--    Function / scheduled job manually).
-- =============================================================================

create or replace function public.cleanup_expired_stories()
returns integer
language plpgsql
security definer
set search_path = public, storage
as $$
declare
  v_deleted integer := 0;
  r record;
  v_still_referenced boolean;
begin
  for r in
    select id, media_path
    from public.stories
    where expires_at <= now()
    for update skip locked
  loop
    v_still_referenced := exists (
      select 1 from public.profile_media pm
      where pm.storage_path = r.media_path
    ) or exists (
      select 1 from public.business_media bm
      where bm.storage_path = r.media_path
    ) or exists (
      select 1 from public.professional_media prm
      where prm.storage_path = r.media_path
    ) or exists (
      select 1 from public.community_news_post_media cpm
      where cpm.storage_path = r.media_path
    );

    -- Always remove the Story record after expiration.
    delete from public.stories where id = r.id;
    v_deleted := v_deleted + 1;

    -- Only remove dedicated storage when nothing else references the path.
    if not v_still_referenced and r.media_path is not null
       and length(trim(r.media_path)) > 0 then
      begin
        delete from storage.objects
        where bucket_id in ('profile-media', 'profile', 'media', 'stories')
          and name = r.media_path;
      exception
        when undefined_table then null;
        when others then null;
      end;
    end if;
  end loop;

  return v_deleted;
end;
$$;

revoke all on function public.cleanup_expired_stories() from public;
-- Executable only by service role / postgres; do not expose to anon/authenticated.

-- Schedule when pg_cron is available.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'cleanup-expired-stories') then
      perform cron.unschedule('cleanup-expired-stories');
    end if;
    perform cron.schedule(
      'cleanup-expired-stories',
      '15 * * * *',
      $cron$ select public.cleanup_expired_stories(); $cron$
    );
  end if;
exception
  when others then
    raise notice 'pg_cron schedule skipped: %', sqlerrm;
end $$;
