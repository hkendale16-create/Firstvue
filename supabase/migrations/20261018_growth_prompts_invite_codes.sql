-- Growth prompts: referral-ready invite codes + analytics event names.
-- No rewards program. Invite codes are public/random, not auth IDs.

alter table public.profiles
  add column if not exists invite_code text;

create unique index if not exists profiles_invite_code_uidx
  on public.profiles (invite_code)
  where invite_code is not null;

comment on column public.profiles.invite_code is
  'Public referral-ready invitation code. Not a sensitive identifier.';

create or replace function public.fv_ensure_invite_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_i int;
  v_attempt int;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select invite_code into v_code
  from public.profiles
  where id = v_uid;

  if v_code is not null and length(v_code) = 8 then
    return v_code;
  end if;

  for v_attempt in 1..12 loop
    v_code := '';
    for v_i in 1..8 loop
      v_code := v_code || substr(
        v_alphabet,
        1 + floor(random() * length(v_alphabet))::int,
        1
      );
    end loop;

    begin
      update public.profiles
      set invite_code = v_code, updated_at = now()
      where id = v_uid;
      return v_code;
    exception
      when unique_violation then
        v_code := null;
    end;
  end loop;

  raise exception 'Unable to allocate invite code';
end;
$$;

revoke all on function public.fv_ensure_invite_code() from public;
grant execute on function public.fv_ensure_invite_code() to authenticated;

alter table public.product_events
  drop constraint if exists product_events_name_ok;

alter table public.product_events
  add constraint product_events_name_ok check (
    event_name in (
      'account_created',
      'onboarding_completed',
      'vue_viewed',
      'vue_completed',
      'vue_liked',
      'vue_commented',
      'vue_shared',
      'vue_saved',
      'event_viewed',
      'event_saved',
      'event_interested',
      'event_shared',
      'event_chat_opened',
      'business_viewed',
      'business_followed',
      'profile_viewed',
      'user_followed',
      'search_performed',
      'group_viewed',
      'community_viewed',
      'message_started',
      'feedback_opened',
      'feedback_submitted',
      'idea_submitted',
      'idea_voted',
      'early_access_prompt_shown',
      'early_access_prompt_dismissed',
      'pmf_survey_answered',
      'growth_prompt_seen',
      'growth_prompt_clicked',
      'post_started',
      'post_completed',
      'media_uploaded',
      'event_explored',
      'invite_started',
      'invite_shared'
    )
  );
