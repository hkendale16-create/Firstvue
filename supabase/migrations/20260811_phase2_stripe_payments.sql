-- Phase 2: Stripe subscription billing support.

alter table public.business_subscriptions
  add column if not exists updated_at timestamptz not null default now();

delete from public.business_subscriptions a
using public.business_subscriptions b
where a.business_id = b.business_id
  and a.created_at < b.created_at;

create unique index if not exists business_subscriptions_business_id_uidx
  on public.business_subscriptions (business_id);

create table if not exists public.stripe_webhook_events (
  event_id text primary key,
  event_type text not null,
  payload jsonb,
  processed_at timestamptz not null default now()
);

alter table public.stripe_webhook_events enable row level security;

-- Webhook table is service-role only (no client policies).

create or replace function public.sync_business_subscription_from_stripe(
  p_business_id uuid,
  p_plan text,
  p_price_cents integer,
  p_status text,
  p_provider_customer_id text,
  p_provider_subscription_id text,
  p_current_period_ends_at timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.business_subscriptions (
    business_id,
    plan,
    price_cents,
    status,
    provider_customer_id,
    provider_subscription_id,
    current_period_ends_at,
    updated_at
  )
  values (
    p_business_id,
    p_plan,
    p_price_cents,
    p_status,
    p_provider_customer_id,
    p_provider_subscription_id,
    p_current_period_ends_at,
    now()
  )
  on conflict (business_id) do update
    set plan = excluded.plan,
        price_cents = excluded.price_cents,
        status = excluded.status,
        provider_customer_id = excluded.provider_customer_id,
        provider_subscription_id = excluded.provider_subscription_id,
        current_period_ends_at = excluded.current_period_ends_at,
        updated_at = now();

  if p_plan in ('verified', 'pro') and p_status in ('trialing', 'active') then
    update public.businesses
    set verification_status = 'verified',
        updated_at = now()
    where id = p_business_id;
  elsif p_status in ('canceled', 'past_due') then
    update public.businesses
    set verification_status = case
          when verification_status = 'verified' then 'pending'
          else verification_status
        end,
        updated_at = now()
    where id = p_business_id;
  end if;
end;
$$;

revoke all on function public.sync_business_subscription_from_stripe(
  uuid, text, integer, text, text, text, timestamptz
) from public;

-- Only the service role (Edge Functions webhook) should call this RPC.
