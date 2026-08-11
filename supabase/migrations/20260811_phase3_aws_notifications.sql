-- Phase 3: AWS SES notification outbox + database triggers.
-- Pair with Edge Function: send-email
-- Pair with Supabase Database Webhook: INSERT on email_outbox → send-email

create table if not exists public.email_outbox (
  id uuid primary key default gen_random_uuid(),
  template text not null,
  recipient_email text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'failed', 'skipped')),
  error_message text,
  idempotency_key text unique,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create index if not exists email_outbox_pending_idx
  on public.email_outbox (status, created_at)
  where status = 'pending';

alter table public.email_outbox enable row level security;

-- Outbox is service-role only; clients never read or write email jobs.

create or replace function public.get_auth_user_email(p_user_id uuid)
returns text
language sql
security definer
set search_path = public, auth
stable
as $$
  select email from auth.users where id = p_user_id;
$$;

revoke all on function public.get_auth_user_email(uuid) from public;

create or replace function public.enqueue_email_notification(
  p_template text,
  p_recipient_email text,
  p_payload jsonb,
  p_idempotency_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient_email is null or length(trim(p_recipient_email)) = 0 then
    return;
  end if;

  insert into public.email_outbox (
    template,
    recipient_email,
    payload,
    idempotency_key
  )
  values (
    p_template,
    trim(p_recipient_email),
    coalesce(p_payload, '{}'::jsonb),
    p_idempotency_key
  )
  on conflict (idempotency_key) do nothing;
end;
$$;

revoke all on function public.enqueue_email_notification(text, text, jsonb, text) from public;

-- Businesses approved / rejected
create or replace function public.trg_enqueue_business_status_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'pending' then
    return new;
  end if;

  v_email := public.get_auth_user_email(new.created_by);

  perform public.enqueue_email_notification(
    case
      when new.status = 'approved' then 'business_approved'
      when new.status = 'rejected' then 'business_rejected'
      else 'business_status_updated'
    end,
    v_email,
    jsonb_build_object(
      'business_id', new.id,
      'business_name', new.name,
      'status', new.status
    ),
    'business_status:' || new.id::text || ':' || new.status
  );

  return new;
end;
$$;

drop trigger if exists enqueue_business_status_email on public.businesses;
create trigger enqueue_business_status_email
  after update of status on public.businesses
  for each row
  execute function public.trg_enqueue_business_status_email();

-- Rentals approved / rejected
create or replace function public.trg_enqueue_rental_status_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  if new.status not in ('approved', 'rejected') then
    return new;
  end if;

  v_email := public.get_auth_user_email(new.owner_id);

  perform public.enqueue_email_notification(
    case
      when new.status = 'approved' then 'rental_approved'
      else 'rental_rejected'
    end,
    v_email,
    jsonb_build_object(
      'rental_id', new.id,
      'title', new.title,
      'status', new.status
    ),
    'rental_status:' || new.id::text || ':' || new.status
  );

  return new;
end;
$$;

drop trigger if exists enqueue_rental_status_email on public.rentals;
create trigger enqueue_rental_status_email
  after update of status on public.rentals
  for each row
  execute function public.trg_enqueue_rental_status_email();

-- Business reviews approved / rejected
create or replace function public.trg_enqueue_review_status_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_business_name text;
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  if new.status not in ('approved', 'rejected') then
    return new;
  end if;

  v_email := public.get_auth_user_email(new.reviewer_id);

  select name into v_business_name
  from public.businesses
  where id = new.business_id;

  perform public.enqueue_email_notification(
    case
      when new.status = 'approved' then 'review_approved'
      else 'review_rejected'
    end,
    v_email,
    jsonb_build_object(
      'review_id', new.id,
      'business_name', coalesce(v_business_name, 'your business'),
      'status', new.status
    ),
    'review_status:' || new.id::text || ':' || new.status
  );

  return new;
end;
$$;

drop trigger if exists enqueue_review_status_email on public.business_reviews;
create trigger enqueue_review_status_email
  after update of status on public.business_reviews
  for each row
  execute function public.trg_enqueue_review_status_email();

-- Professional profiles approved / rejected
create or replace function public.trg_enqueue_professional_status_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  if tg_op <> 'UPDATE' or old.status is not distinct from new.status then
    return new;
  end if;

  if new.status not in ('approved', 'rejected') then
    return new;
  end if;

  v_email := public.get_auth_user_email(new.profile_id);

  perform public.enqueue_email_notification(
    case
      when new.status = 'approved' then 'professional_approved'
      else 'professional_rejected'
    end,
    v_email,
    jsonb_build_object(
      'professional_id', new.id,
      'display_name', new.display_name,
      'status', new.status
    ),
    'professional_status:' || new.id::text || ':' || new.status
  );

  return new;
end;
$$;

drop trigger if exists enqueue_professional_status_email on public.professional_profiles;
create trigger enqueue_professional_status_email
  after update of status on public.professional_profiles
  for each row
  execute function public.trg_enqueue_professional_status_email();

-- Rental inquiry → notify owner
create or replace function public.trg_enqueue_rental_inquiry_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_owner_email text;
  v_title text;
begin
  select r.owner_id, r.title
  into v_owner_id, v_title
  from public.rentals r
  where r.id = new.rental_id;

  v_owner_email := public.get_auth_user_email(v_owner_id);

  perform public.enqueue_email_notification(
    'rental_inquiry_received',
    v_owner_email,
    jsonb_build_object(
      'rental_id', new.rental_id,
      'rental_title', coalesce(v_title, 'your rental'),
      'inquiry_id', new.id,
      'message_preview', left(coalesce(new.message, ''), 180)
    ),
    'rental_inquiry:' || new.id::text
  );

  return new;
end;
$$;

drop trigger if exists enqueue_rental_inquiry_email on public.rental_inquiries;
create trigger enqueue_rental_inquiry_email
  after insert on public.rental_inquiries
  for each row
  execute function public.trg_enqueue_rental_inquiry_email();

-- New pending business → admin alert (recipient resolved in Edge Function)
create or replace function public.trg_enqueue_admin_business_submission_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;

  perform public.enqueue_email_notification(
    'admin_new_business_submission',
    'admin@firstvue.internal',
    jsonb_build_object(
      'business_id', new.id,
      'business_name', new.name,
      'created_by', new.created_by
    ),
    'admin_business_submission:' || new.id::text
  );

  return new;
end;
$$;

drop trigger if exists enqueue_admin_business_submission_email on public.businesses;
create trigger enqueue_admin_business_submission_email
  after insert on public.businesses
  for each row
  execute function public.trg_enqueue_admin_business_submission_email();

-- Subscription activated → notify business owner
create or replace function public.trg_enqueue_subscription_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
  v_owner_email text;
  v_business_name text;
begin
  if tg_op = 'INSERT' then
    if new.status not in ('active', 'trialing') then
      return new;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.status is not distinct from new.status then
      return new;
    end if;
    if new.status not in ('active', 'trialing') then
      return new;
    end if;
    if old.status in ('active', 'trialing') then
      return new;
    end if;
  end if;

  select b.created_by, b.name
  into v_owner_id, v_business_name
  from public.businesses b
  where b.id = new.business_id;

  v_owner_email := public.get_auth_user_email(v_owner_id);

  perform public.enqueue_email_notification(
    'subscription_activated',
    v_owner_email,
    jsonb_build_object(
      'business_id', new.business_id,
      'business_name', coalesce(v_business_name, 'your business'),
      'plan', new.plan,
      'status', new.status
    ),
    'subscription_activated:' || new.business_id::text || ':' || new.plan
  );

  return new;
end;
$$;

-- Subscription activated → notify business owner (when subscriptions table exists)
do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'business_subscriptions'
  ) then
    drop trigger if exists enqueue_subscription_email on public.business_subscriptions;
    create trigger enqueue_subscription_email
      after insert or update of status, plan on public.business_subscriptions
      for each row
      execute function public.trg_enqueue_subscription_email();
  end if;
end $$;
