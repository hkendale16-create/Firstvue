-- Monetization + VUE Bounties foundation.
-- Prototype-ready schema. Real-money mutations are RPC/service-role only.
-- Do NOT describe funds as legal escrow. Funding/payouts stay feature-flagged.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.fv_owns_business(p_business_id uuid, p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.businesses b
    where b.id = p_business_id
      and (
        b.created_by = p_uid
        or public.has_business_role(b.id, array['owner', 'manager'], p_uid)
      )
  );
$$;

revoke all on function public.fv_owns_business(uuid, uuid) from public;
grant execute on function public.fv_owns_business(uuid, uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Central product / pricing config (never hardcode prices in app logic)
-- ---------------------------------------------------------------------------

create table if not exists public.monetization_products (
  id text primary key,
  display_name text not null,
  product_family text not null check (
    product_family in (
      'consumer_plus',
      'business_subscription',
      'business_boost',
      'event_boost',
      'bounty_campaign',
      'affiliate_program',
      'other'
    )
  ),
  billing_period text check (billing_period is null or billing_period in ('month', 'year', 'one_time', 'usage')),
  price_cents integer check (price_cents is null or price_cents >= 0),
  currency text not null default 'usd',
  stripe_price_id text,
  apple_product_id text,
  google_product_id text,
  platform_fee_bps integer not null default 1500 check (platform_fee_bps between 0 and 10000),
  is_active boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.monetization_feature_flags (
  flag_key text primary key,
  enabled boolean not null default false,
  description text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

insert into public.monetization_products (
  id, display_name, product_family, billing_period, price_cents, platform_fee_bps, is_active, metadata
) values
  ('firstvue_plus', 'FirstVue+', 'consumer_plus', 'month', null, 0, false,
    '{"note":"Optional consumer tier — not priced or activated yet"}'::jsonb),
  ('business_verified', 'FirstVue Verified', 'business_subscription', 'month', 999, 0, false,
    '{"legacy_plan":"verified"}'::jsonb),
  ('business_pro', 'FirstVue Pro', 'business_subscription', 'month', 2999, 0, false,
    '{"legacy_plan":"pro","target_note":"Conceptual ~$29.99/mo — configure via this row"}'::jsonb),
  ('vue_bounty_default', 'VUE Bounty Campaign', 'bounty_campaign', 'one_time', null, 1500, false,
    '{"fee_range_note":"Conceptual 15–20% — configure platform_fee_bps per campaign/product"}'::jsonb),
  ('share_and_earn_default', 'Share & Earn', 'affiliate_program', 'usage', null, 0, false,
    '{"note":"Referral reward amount set per program"}'::jsonb)
on conflict (id) do nothing;

insert into public.monetization_feature_flags (flag_key, enabled, description) values
  ('business_subscriptions', false, 'Stripe/IAP business plan upgrades'),
  ('business_boosts', false, 'Paid business/event boost placements'),
  ('vue_bounties', true, 'Bounty architecture + discovery UI (no funding)'),
  ('bounty_funding', false, 'Real campaign funding authorization'),
  ('creator_payouts', false, 'Creator cash withdrawals / payouts'),
  ('affiliate_rewards', false, 'Share & Earn cash rewards'),
  ('ticketing', false, 'Paid ticketing / ticket conversions')
on conflict (flag_key) do nothing;

alter table public.monetization_products enable row level security;
alter table public.monetization_feature_flags enable row level security;

drop policy if exists "Anyone reads monetization products" on public.monetization_products;
create policy "Anyone reads monetization products"
  on public.monetization_products for select to anon, authenticated using (true);

drop policy if exists "Anyone reads monetization feature flags" on public.monetization_feature_flags;
create policy "Anyone reads monetization feature flags"
  on public.monetization_feature_flags for select to anon, authenticated using (true);

-- Writes: service role / admin RPC only (no client insert/update policies).

-- ---------------------------------------------------------------------------
-- Subscription entitlements (Apple / Google / Stripe) — separate from profiles
-- ---------------------------------------------------------------------------

create table if not exists public.subscription_entitlements (
  id uuid primary key default gen_random_uuid(),
  subject_type text not null check (subject_type in ('profile', 'business')),
  subject_id uuid not null,
  product_id text not null references public.monetization_products(id),
  platform text not null check (platform in ('stripe', 'apple', 'google', 'manual', 'promo')),
  status text not null check (
    status in ('none', 'pending', 'active', 'grace_period', 'expired', 'revoked', 'refunded')
  ),
  purchase_state text not null default 'none' check (
    purchase_state in ('none', 'purchased', 'restored', 'canceled', 'expired', 'refunded', 'deferred')
  ),
  renews boolean not null default false,
  expires_at timestamptz,
  original_transaction_ref text,
  latest_transaction_ref text,
  store_environment text check (
    store_environment is null or store_environment in ('sandbox', 'production', 'test')
  ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subject_type, subject_id, product_id, platform)
);

create table if not exists public.subscription_transactions (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid references public.subscription_entitlements(id) on delete set null,
  subject_type text not null check (subject_type in ('profile', 'business')),
  subject_id uuid not null,
  product_id text not null references public.monetization_products(id),
  platform text not null check (platform in ('stripe', 'apple', 'google', 'manual', 'promo')),
  transaction_ref text not null,
  original_transaction_ref text,
  purchase_state text not null,
  amount_cents integer check (amount_cents is null or amount_cents >= 0),
  currency text not null default 'usd',
  purchased_at timestamptz,
  expires_at timestamptz,
  raw_payload jsonb,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  unique (platform, transaction_ref)
);

create index if not exists subscription_entitlements_subject_idx
  on public.subscription_entitlements (subject_type, subject_id, status);
create index if not exists subscription_transactions_subject_idx
  on public.subscription_transactions (subject_type, subject_id, created_at desc);

alter table public.subscription_entitlements enable row level security;
alter table public.subscription_transactions enable row level security;

drop policy if exists "Subjects read own entitlements" on public.subscription_entitlements;
create policy "Subjects read own entitlements"
  on public.subscription_entitlements for select to authenticated
  using (
    (subject_type = 'profile' and subject_id = auth.uid())
    or (subject_type = 'business' and public.fv_owns_business(subject_id))
    or public.is_firstvue_admin()
  );

drop policy if exists "Subjects read own subscription transactions" on public.subscription_transactions;
create policy "Subjects read own subscription transactions"
  on public.subscription_transactions for select to authenticated
  using (
    (subject_type = 'profile' and subject_id = auth.uid())
    or (subject_type = 'business' and public.fv_owns_business(subject_id))
    or public.is_firstvue_admin()
  );

-- ---------------------------------------------------------------------------
-- Creator profiles + reputation (clients cannot modify reputation)
-- ---------------------------------------------------------------------------

create table if not exists public.creator_profiles (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  display_label text,
  bio text,
  is_eligible boolean not null default true,
  payout_ready boolean not null default false,
  preferred_categories text[] not null default '{}',
  home_city text,
  home_state text,
  home_latitude double precision,
  home_longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.creator_reputation (
  profile_id uuid primary key references public.creator_profiles(profile_id) on delete cascade,
  level_key text not null default 'new_creator' check (
    level_key in ('new_creator', 'local_creator', 'trusted_creator', 'featured_creator')
  ),
  completed_campaigns integer not null default 0 check (completed_campaigns >= 0),
  accepted_campaigns integer not null default 0 check (accepted_campaigns >= 0),
  completion_bps integer not null default 0 check (completion_bps between 0 and 10000),
  verified_conversions integer not null default 0 check (verified_conversions >= 0),
  reliability_score integer not null default 0 check (reliability_score between 0 and 10000),
  policy_violations integer not null default 0 check (policy_violations >= 0),
  business_feedback_score integer check (business_feedback_score is null or business_feedback_score between 0 and 5000),
  follower_count_snapshot integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.creator_profiles enable row level security;
alter table public.creator_reputation enable row level security;

drop policy if exists "Creators manage own profile row" on public.creator_profiles;
create policy "Creators manage own profile row"
  on public.creator_profiles for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Public reads eligible creator profiles" on public.creator_profiles;
create policy "Public reads eligible creator profiles"
  on public.creator_profiles for select to anon, authenticated
  using (is_eligible or profile_id = auth.uid() or public.is_firstvue_admin());

drop policy if exists "Anyone reads creator reputation" on public.creator_reputation;
create policy "Anyone reads creator reputation"
  on public.creator_reputation for select to anon, authenticated using (true);

-- No client write policies on creator_reputation.

-- ---------------------------------------------------------------------------
-- VUE Bounty campaigns (fixed / performance / hybrid in one system)
-- ---------------------------------------------------------------------------

create table if not exists public.bounty_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text,
  description text,
  bounty_type text not null check (bounty_type in ('fixed', 'performance', 'hybrid')),
  status text not null default 'draft' check (
    status in (
      'draft',
      'awaiting_funding',
      'funded_authorized',
      'active',
      'completed',
      'cancelled',
      'refunding',
      'refunded'
    )
  ),
  sponsor_type text not null check (
    sponsor_type in (
      'business', 'event', 'venue', 'restaurant', 'bar_nightlife',
      'entrepreneur', 'popup', 'other'
    )
  ),
  business_id uuid references public.businesses(id) on delete set null,
  event_id uuid references public.community_events(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  product_id text references public.monetization_products(id) default 'vue_bounty_default',
  location_label text,
  city text,
  state text,
  latitude double precision,
  longitude double precision,
  -- Money in integer minor units (cents)
  creator_pool_cents integer not null check (creator_pool_cents >= 0),
  max_campaign_budget_cents integer not null check (max_campaign_budget_cents >= 0),
  max_creator_payout_cents integer not null check (max_creator_payout_cents >= 0),
  fixed_payout_cents integer not null default 0 check (fixed_payout_cents >= 0),
  performance_payout_cents integer not null default 0 check (performance_payout_cents >= 0),
  platform_fee_bps integer not null default 1500 check (platform_fee_bps between 0 and 10000),
  creators_wanted integer not null check (creators_wanted > 0),
  creators_accepted integer not null default 0 check (creators_accepted >= 0),
  starts_at timestamptz,
  ends_at timestamptz,
  submission_deadline_at timestamptz,
  current_requirements_version integer not null default 1,
  disclosure_label text not null default 'VUE Bounty',
  funding_authorized_at timestamptz,
  funding_provider_ref text,
  cancelled_at timestamptz,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bounty_campaigns_budget_bounds check (
    max_campaign_budget_cents >= creator_pool_cents
    and max_creator_payout_cents <= max_campaign_budget_cents
  ),
  constraint bounty_campaigns_type_money check (
    (bounty_type = 'fixed' and fixed_payout_cents > 0)
    or (bounty_type = 'performance' and performance_payout_cents > 0)
    or (bounty_type = 'hybrid' and fixed_payout_cents > 0 and performance_payout_cents > 0)
  ),
  constraint bounty_campaigns_window check (
    starts_at is null or ends_at is null or ends_at > starts_at
  )
);

create table if not exists public.bounty_requirement_versions (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.bounty_campaigns(id) on delete cascade,
  version integer not null check (version > 0),
  locked_at timestamptz,
  locked_reason text,
  event_date date,
  location_label text,
  attendance_window_start timestamptz,
  attendance_window_end timestamptz,
  vue_min_seconds integer check (vue_min_seconds is null or vue_min_seconds > 0),
  vue_max_seconds integer check (vue_max_seconds is null or vue_max_seconds > 0),
  content_category text,
  required_tag text,
  submission_deadline_at timestamptz,
  creators_wanted integer,
  campaign_description text,
  deliverables text,
  compensation_summary text,
  performance_bonus_summary text,
  max_payout_cents integer,
  requirements jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  unique (campaign_id, version),
  constraint bounty_req_vue_bounds check (
    vue_min_seconds is null
    or vue_max_seconds is null
    or vue_max_seconds >= vue_min_seconds
  )
);

create table if not exists public.bounty_applications (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.bounty_campaigns(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'applied' check (
    status in (
      'applied',
      'accepted',
      'declined',
      'withdrawn',
      'in_progress',
      'submitted',
      'under_review',
      'completed',
      'disputed',
      'cancelled'
    )
  ),
  requirements_version integer not null,
  message text,
  accepted_at timestamptz,
  withdrawn_at timestamptz,
  declined_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (campaign_id, creator_id)
);

create table if not exists public.bounty_submissions (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.bounty_applications(id) on delete cascade,
  campaign_id uuid not null references public.bounty_campaigns(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  news_post_id uuid references public.community_news_posts(id) on delete set null,
  media_id uuid,
  requirements_version integer not null,
  status text not null default 'submitted' check (
    status in ('submitted', 'under_review', 'approved', 'rejected', 'disputed', 'withdrawn')
  ),
  disclosure_shown boolean not null default true,
  business_notes text,
  rejection_reason text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (application_id)
);

create index if not exists bounty_campaigns_status_geo_idx
  on public.bounty_campaigns (status, latitude, longitude);
create index if not exists bounty_campaigns_business_idx
  on public.bounty_campaigns (business_id, status);
create index if not exists bounty_campaigns_event_idx
  on public.bounty_campaigns (event_id, status);
create index if not exists bounty_campaigns_active_ends_idx
  on public.bounty_campaigns (status, ends_at);
create index if not exists bounty_applications_creator_idx
  on public.bounty_applications (creator_id, status, created_at desc);
create index if not exists bounty_applications_campaign_idx
  on public.bounty_applications (campaign_id, status);
create index if not exists bounty_submissions_campaign_idx
  on public.bounty_submissions (campaign_id, status, submitted_at desc);

alter table public.bounty_campaigns enable row level security;
alter table public.bounty_requirement_versions enable row level security;
alter table public.bounty_applications enable row level security;
alter table public.bounty_submissions enable row level security;

drop policy if exists "Public reads discoverable bounties" on public.bounty_campaigns;
create policy "Public reads discoverable bounties"
  on public.bounty_campaigns for select to anon, authenticated
  using (
    status in ('active', 'funded_authorized', 'completed')
    or created_by = auth.uid()
    or (business_id is not null and public.fv_owns_business(business_id))
    or public.is_firstvue_admin()
  );

drop policy if exists "Owners insert draft bounties" on public.bounty_campaigns;
create policy "Owners insert draft bounties"
  on public.bounty_campaigns for insert to authenticated
  with check (
    created_by = auth.uid()
    and status = 'draft'
    and (
      business_id is null
      or public.fv_owns_business(business_id)
    )
  );

drop policy if exists "Owners update own draft bounties" on public.bounty_campaigns;
create policy "Owners update own draft bounties"
  on public.bounty_campaigns for update to authenticated
  using (
    created_by = auth.uid()
    or (business_id is not null and public.fv_owns_business(business_id))
    or public.is_firstvue_admin()
  )
  with check (
    created_by = auth.uid()
    or (business_id is not null and public.fv_owns_business(business_id))
    or public.is_firstvue_admin()
  );

-- Note: funding/status elevation to funded/active must go through SECURITY DEFINER RPCs
-- when bounty_funding is enabled. Client updates that change money fields are blocked
-- by trigger below.

drop policy if exists "Read bounty requirements with campaign" on public.bounty_requirement_versions;
create policy "Read bounty requirements with campaign"
  on public.bounty_requirement_versions for select to anon, authenticated
  using (
    exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.status in ('active', 'funded_authorized', 'completed')
          or c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
          or public.is_firstvue_admin()
        )
    )
  );

drop policy if exists "Owners manage unlocked requirements" on public.bounty_requirement_versions;
create policy "Owners manage unlocked requirements"
  on public.bounty_requirement_versions for all to authenticated
  using (
    locked_at is null
    and exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
          or public.is_firstvue_admin()
        )
    )
  )
  with check (
    exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
          or public.is_firstvue_admin()
        )
    )
  );

drop policy if exists "Creators manage own applications" on public.bounty_applications;
create policy "Creators manage own applications"
  on public.bounty_applications for select to authenticated
  using (
    creator_id = auth.uid()
    or exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
        )
    )
    or public.is_firstvue_admin()
  );

drop policy if exists "Creators insert applications" on public.bounty_applications;
create policy "Creators insert applications"
  on public.bounty_applications for insert to authenticated
  with check (
    creator_id = auth.uid()
    and status = 'applied'
    and exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id and c.status = 'active'
    )
  );

drop policy if exists "Creators withdraw own applications" on public.bounty_applications;
create policy "Creators withdraw own applications"
  on public.bounty_applications for update to authenticated
  using (creator_id = auth.uid() or public.is_firstvue_admin()
    or exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
        )
    ))
  with check (creator_id = auth.uid() or public.is_firstvue_admin()
    or exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
        )
    ));

drop policy if exists "Participants read submissions" on public.bounty_submissions;
create policy "Participants read submissions"
  on public.bounty_submissions for select to authenticated
  using (
    creator_id = auth.uid()
    or exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
        )
    )
    or public.is_firstvue_admin()
  );

drop policy if exists "Creators insert submissions" on public.bounty_submissions;
create policy "Creators insert submissions"
  on public.bounty_submissions for insert to authenticated
  with check (
    creator_id = auth.uid()
    and exists (
      select 1 from public.bounty_applications a
      where a.id = application_id
        and a.creator_id = auth.uid()
        and a.status in ('accepted', 'in_progress', 'submitted', 'under_review')
    )
  );

-- ---------------------------------------------------------------------------
-- Immutable financial ledger (not a bank / not a stored-value wallet)
-- ---------------------------------------------------------------------------

create table if not exists public.financial_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  entry_type text not null check (
    entry_type in (
      'campaign_funding_auth',
      'campaign_funding_capture',
      'platform_fee',
      'creator_earning_pending',
      'creator_earning_available',
      'creator_earning_clawback',
      'affiliate_earning_pending',
      'affiliate_earning_available',
      'affiliate_earning_clawback',
      'payout_initiated',
      'payout_completed',
      'payout_failed',
      'refund',
      'adjustment'
    )
  ),
  amount_cents integer not null check (amount_cents <> 0),
  currency text not null default 'usd',
  direction text not null check (direction in ('credit', 'debit')),
  status text not null default 'posted' check (
    status in ('pending', 'posted', 'voided', 'reversed')
  ),
  profile_id uuid references public.profiles(id) on delete set null,
  business_id uuid references public.businesses(id) on delete set null,
  campaign_id uuid references public.bounty_campaigns(id) on delete set null,
  application_id uuid references public.bounty_applications(id) on delete set null,
  conversion_id uuid,
  payout_id uuid,
  idempotency_key text not null,
  narrative text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  created_by_role text not null default 'system',
  unique (idempotency_key)
);

create table if not exists public.payout_records (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete restrict,
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'usd',
  status text not null default 'pending' check (
    status in ('pending', 'processing', 'paid', 'failed', 'cancelled')
  ),
  provider text,
  provider_payout_ref text,
  failure_reason text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists financial_ledger_profile_idx
  on public.financial_ledger_entries (profile_id, created_at desc);
create index if not exists financial_ledger_campaign_idx
  on public.financial_ledger_entries (campaign_id, created_at desc);
create index if not exists payout_records_profile_idx
  on public.payout_records (profile_id, status, requested_at desc);

alter table public.financial_ledger_entries enable row level security;
alter table public.payout_records enable row level security;

drop policy if exists "Users read own ledger entries" on public.financial_ledger_entries;
create policy "Users read own ledger entries"
  on public.financial_ledger_entries for select to authenticated
  using (
    profile_id = auth.uid()
    or (business_id is not null and public.fv_owns_business(business_id))
    or public.is_firstvue_admin()
  );

drop policy if exists "Users read own payout records" on public.payout_records;
create policy "Users read own payout records"
  on public.payout_records for select to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin());

-- No insert/update/delete policies for clients on ledger or payouts.

create or replace view public.creator_earnings_balances
with (security_invoker = true)
as
select
  profile_id,
  coalesce(sum(case
    when entry_type = 'creator_earning_available'
      and direction = 'credit'
      and status = 'posted'
    then amount_cents
    when entry_type in ('creator_earning_clawback', 'payout_initiated', 'payout_completed')
      and direction = 'debit'
      and status = 'posted'
    then -amount_cents
    else 0
  end), 0)::integer as available_cents,
  coalesce(sum(case
    when entry_type = 'creator_earning_pending'
      and direction = 'credit'
      and status in ('pending', 'posted')
    then amount_cents
    else 0
  end), 0)::integer as pending_cents,
  coalesce(sum(case
    when entry_type in ('creator_earning_pending', 'creator_earning_available')
      and direction = 'credit'
      and status in ('pending', 'posted')
    then amount_cents
    else 0
  end), 0)::integer as lifetime_cents
from public.financial_ledger_entries
where profile_id is not null
group by profile_id;

revoke all on public.creator_earnings_balances from anon;
grant select on public.creator_earnings_balances to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Share & Earn / affiliates
-- ---------------------------------------------------------------------------

create table if not exists public.affiliate_programs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.community_events(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'draft' check (
    status in ('draft', 'active', 'paused', 'ended', 'cancelled')
  ),
  reward_cents integer not null check (reward_cents > 0),
  currency text not null default 'usd',
  attribution_window_hours integer not null default 168 check (attribution_window_hours > 0),
  max_program_budget_cents integer not null check (max_program_budget_cents > 0),
  max_reward_per_creator_cents integer check (
    max_reward_per_creator_cents is null or max_reward_per_creator_cents > 0
  ),
  competing_attribution_rule text not null default 'last_click_wins' check (
    competing_attribution_rule in ('last_click_wins', 'first_click_wins')
  ),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.affiliate_attributions (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.affiliate_programs(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  event_id uuid references public.community_events(id) on delete set null,
  attribution_code text not null,
  click_id text,
  buyer_profile_id uuid references public.profiles(id) on delete set null,
  attributed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  status text not null default 'active' check (
    status in ('active', 'converted', 'expired', 'superseded', 'invalid')
  ),
  fraud_status text not null default 'none' check (
    fraud_status in ('none', 'suspected', 'confirmed', 'cleared')
  ),
  metadata jsonb not null default '{}'::jsonb,
  unique (program_id, attribution_code)
);

create table if not exists public.affiliate_conversions (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.affiliate_programs(id) on delete cascade,
  attribution_id uuid not null references public.affiliate_attributions(id) on delete restrict,
  creator_id uuid not null references public.profiles(id) on delete restrict,
  event_id uuid references public.community_events(id) on delete set null,
  buyer_profile_id uuid references public.profiles(id) on delete set null,
  conversion_external_id text not null,
  order_reference text,
  reward_cents integer not null check (reward_cents > 0),
  verified_at timestamptz,
  verification_status text not null default 'unverified' check (
    verification_status in ('unverified', 'verified', 'rejected')
  ),
  refund_status text not null default 'none' check (
    refund_status in ('none', 'pending', 'refunded', 'chargeback')
  ),
  fraud_status text not null default 'none' check (
    fraud_status in ('none', 'suspected', 'confirmed', 'cleared')
  ),
  created_at timestamptz not null default now(),
  unique (program_id, conversion_external_id)
);

create index if not exists affiliate_programs_event_idx
  on public.affiliate_programs (event_id, status);
create index if not exists affiliate_attributions_creator_idx
  on public.affiliate_attributions (creator_id, status, attributed_at desc);
create index if not exists affiliate_conversions_creator_idx
  on public.affiliate_conversions (creator_id, verification_status, created_at desc);

alter table public.affiliate_programs enable row level security;
alter table public.affiliate_attributions enable row level security;
alter table public.affiliate_conversions enable row level security;

drop policy if exists "Read affiliate programs" on public.affiliate_programs;
create policy "Read affiliate programs"
  on public.affiliate_programs for select to authenticated
  using (
    status = 'active'
    or created_by = auth.uid()
    or (business_id is not null and public.fv_owns_business(business_id))
    or public.is_firstvue_admin()
  );

drop policy if exists "Owners create affiliate programs" on public.affiliate_programs;
create policy "Owners create affiliate programs"
  on public.affiliate_programs for insert to authenticated
  with check (
    created_by = auth.uid()
    and status = 'draft'
    and (business_id is null or public.fv_owns_business(business_id))
  );

drop policy if exists "Creators read own attributions" on public.affiliate_attributions;
create policy "Creators read own attributions"
  on public.affiliate_attributions for select to authenticated
  using (
    creator_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.affiliate_programs p
      where p.id = program_id
        and (
          p.created_by = auth.uid()
          or (p.business_id is not null and public.fv_owns_business(p.business_id))
        )
    )
  );

drop policy if exists "Creators read own conversions" on public.affiliate_conversions;
create policy "Creators read own conversions"
  on public.affiliate_conversions for select to authenticated
  using (
    creator_id = auth.uid()
    or public.is_firstvue_admin()
    or exists (
      select 1 from public.affiliate_programs p
      where p.id = program_id
        and (
          p.created_by = auth.uid()
          or (p.business_id is not null and public.fv_owns_business(p.business_id))
        )
    )
  );

-- Conversion verification writes: service role / RPC only.

-- ---------------------------------------------------------------------------
-- Disputes, risk, financial audit
-- ---------------------------------------------------------------------------

create table if not exists public.campaign_disputes (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.bounty_campaigns(id) on delete cascade,
  application_id uuid references public.bounty_applications(id) on delete set null,
  submission_id uuid references public.bounty_submissions(id) on delete set null,
  opened_by uuid not null references public.profiles(id) on delete restrict,
  opened_by_role text not null check (opened_by_role in ('creator', 'business', 'admin')),
  business_id uuid references public.businesses(id) on delete set null,
  creator_id uuid references public.profiles(id) on delete set null,
  reason text not null,
  evidence_refs jsonb not null default '[]'::jsonb,
  status text not null default 'open' check (
    status in ('open', 'under_review', 'resolved', 'rejected', 'withdrawn')
  ),
  admin_decision text,
  resolution text,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.account_risk_states (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  risk_state text not null default 'normal' check (
    risk_state in ('normal', 'review', 'restricted', 'suspended')
  ),
  reason text,
  signals jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

create table if not exists public.financial_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_state jsonb,
  after_state jsonb,
  ip_hint text,
  created_at timestamptz not null default now()
);

create index if not exists campaign_disputes_campaign_idx
  on public.campaign_disputes (campaign_id, status, created_at desc);
create index if not exists financial_audit_log_created_idx
  on public.financial_audit_log (created_at desc);
create index if not exists account_risk_states_state_idx
  on public.account_risk_states (risk_state);

alter table public.campaign_disputes enable row level security;
alter table public.account_risk_states enable row level security;
alter table public.financial_audit_log enable row level security;

drop policy if exists "Participants read disputes" on public.campaign_disputes;
create policy "Participants read disputes"
  on public.campaign_disputes for select to authenticated
  using (
    opened_by = auth.uid()
    or creator_id = auth.uid()
    or (business_id is not null and public.fv_owns_business(business_id))
    or public.is_firstvue_admin()
  );

drop policy if exists "Participants open disputes" on public.campaign_disputes;
create policy "Participants open disputes"
  on public.campaign_disputes for insert to authenticated
  with check (opened_by = auth.uid());

drop policy if exists "Users read own risk state" on public.account_risk_states;
create policy "Users read own risk state"
  on public.account_risk_states for select to authenticated
  using (profile_id = auth.uid() or public.is_firstvue_admin());

drop policy if exists "Admins read financial audit log" on public.financial_audit_log;
create policy "Admins read financial audit log"
  on public.financial_audit_log for select to authenticated
  using (public.is_firstvue_admin());

-- ---------------------------------------------------------------------------
-- Campaign metrics (only from real tracked data; no manufactured ROI)
-- ---------------------------------------------------------------------------

create table if not exists public.bounty_campaign_metrics (
  campaign_id uuid primary key references public.bounty_campaigns(id) on delete cascade,
  applications_count integer not null default 0,
  accepted_creators_count integer not null default 0,
  completed_vues_count integer not null default 0,
  vue_views_count integer not null default 0,
  event_profile_visits integer not null default 0,
  saves_count integer not null default 0,
  shares_count integer not null default 0,
  direction_taps integer not null default 0,
  ticket_conversions integer not null default 0,
  conversion_value_cents integer not null default 0,
  creator_payouts_cents integer not null default 0,
  platform_fees_cents integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.bounty_campaign_metrics enable row level security;

drop policy if exists "Owners read campaign metrics" on public.bounty_campaign_metrics;
create policy "Owners read campaign metrics"
  on public.bounty_campaign_metrics for select to authenticated
  using (
    public.is_firstvue_admin()
    or exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
        )
    )
  );

drop policy if exists "Owners init campaign metrics" on public.bounty_campaign_metrics;
create policy "Owners init campaign metrics"
  on public.bounty_campaign_metrics for insert to authenticated
  with check (
    exists (
      select 1 from public.bounty_campaigns c
      where c.id = campaign_id
        and (
          c.created_by = auth.uid()
          or (c.business_id is not null and public.fv_owns_business(c.business_id))
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Protect money fields + locked requirements
-- ---------------------------------------------------------------------------

create or replace function public.fv_protect_bounty_money_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role'
     or current_user in ('postgres', 'supabase_admin')
     or public.is_firstvue_admin() then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.creator_pool_cents is distinct from old.creator_pool_cents
      or new.max_campaign_budget_cents is distinct from old.max_campaign_budget_cents
      or new.max_creator_payout_cents is distinct from old.max_creator_payout_cents
      or new.fixed_payout_cents is distinct from old.fixed_payout_cents
      or new.performance_payout_cents is distinct from old.performance_payout_cents
      or new.platform_fee_bps is distinct from old.platform_fee_bps
      or new.funding_provider_ref is distinct from old.funding_provider_ref
      or new.funding_authorized_at is distinct from old.funding_authorized_at
    then
      raise exception 'Financial campaign fields are server-controlled';
    end if;

    -- Non-admin clients cannot jump into funded/active/refund states.
    if old.status is distinct from new.status
      and new.status in ('funded_authorized', 'active', 'refunding', 'refunded')
      and old.status in ('draft', 'awaiting_funding', 'cancelled')
    then
      raise exception 'Funding status changes require server authorization';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_bounty_money_fields on public.bounty_campaigns;
create trigger trg_protect_bounty_money_fields
  before update on public.bounty_campaigns
  for each row execute function public.fv_protect_bounty_money_fields();

create or replace function public.fv_prevent_locked_requirement_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role'
     or current_user in ('postgres', 'supabase_admin')
     or public.is_firstvue_admin() then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  if tg_op = 'UPDATE' and old.locked_at is not null then
    raise exception 'Locked campaign requirements cannot be changed';
  end if;
  if tg_op = 'DELETE' and old.locked_at is not null then
    raise exception 'Locked campaign requirements cannot be deleted';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_locked_requirement_edit on public.bounty_requirement_versions;
create trigger trg_prevent_locked_requirement_edit
  before update or delete on public.bounty_requirement_versions
  for each row execute function public.fv_prevent_locked_requirement_edit();

create or replace function public.fv_prevent_ledger_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    if tg_op = 'DELETE' then
      raise exception 'Ledger entries are immutable';
    end if;
    if tg_op = 'UPDATE' and (
      new.amount_cents is distinct from old.amount_cents
      or new.direction is distinct from old.direction
      or new.entry_type is distinct from old.entry_type
      or new.profile_id is distinct from old.profile_id
      or new.idempotency_key is distinct from old.idempotency_key
    ) then
      raise exception 'Ledger monetary fields are immutable';
    end if;
    return new;
  end if;
  raise exception 'Ledger is not client-writable';
end;
$$;

drop trigger if exists trg_prevent_ledger_mutation on public.financial_ledger_entries;
create trigger trg_prevent_ledger_mutation
  before update or delete on public.financial_ledger_entries
  for each row execute function public.fv_prevent_ledger_mutation();

-- Block client inserts into ledger/payouts/reputation/entitlements via trigger
-- as defense-in-depth (RLS already denies; this catches privileged mistakes).

create or replace function public.fv_block_client_financial_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Direct service_role, or SECURITY DEFINER RPCs owned by postgres/supabase_admin.
  if auth.role() = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    return new;
  end if;
  raise exception 'Financial records are not client-writable';
end;
$$;

drop trigger if exists trg_block_ledger_insert on public.financial_ledger_entries;
create trigger trg_block_ledger_insert
  before insert on public.financial_ledger_entries
  for each row execute function public.fv_block_client_financial_insert();

drop trigger if exists trg_block_payout_insert on public.payout_records;
create trigger trg_block_payout_insert
  before insert on public.payout_records
  for each row execute function public.fv_block_client_financial_insert();

drop trigger if exists trg_block_entitlement_insert on public.subscription_entitlements;
create trigger trg_block_entitlement_insert
  before insert on public.subscription_entitlements
  for each row execute function public.fv_block_client_financial_insert();

drop trigger if exists trg_block_sub_tx_insert on public.subscription_transactions;
create trigger trg_block_sub_tx_insert
  before insert on public.subscription_transactions
  for each row execute function public.fv_block_client_financial_insert();

drop trigger if exists trg_block_reputation_write on public.creator_reputation;
create trigger trg_block_reputation_write
  before insert or update or delete on public.creator_reputation
  for each row execute function public.fv_block_client_financial_insert();

-- ---------------------------------------------------------------------------
-- RPCs: safe client operations (no direct money mutation)
-- ---------------------------------------------------------------------------

create or replace function public.fv_ensure_creator_profile()
returns public.creator_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.creator_profiles;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.creator_profiles (profile_id)
  values (v_uid)
  on conflict (profile_id) do nothing;

  insert into public.creator_reputation (profile_id)
  values (v_uid)
  on conflict (profile_id) do nothing;

  select * into v_row from public.creator_profiles where profile_id = v_uid;
  return v_row;
end;
$$;

revoke all on function public.fv_ensure_creator_profile() from public;
grant execute on function public.fv_ensure_creator_profile() to authenticated, service_role;

create or replace function public.fv_apply_to_bounty(
  p_campaign_id uuid,
  p_message text default null
)
returns public.bounty_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_campaign public.bounty_campaigns;
  v_app public.bounty_applications;
  v_recent int;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_campaign from public.bounty_campaigns where id = p_campaign_id for share;
  if not found then
    raise exception 'Campaign not found';
  end if;
  if v_campaign.status <> 'active' then
    raise exception 'Campaign is not open for applications';
  end if;
  if v_campaign.creators_accepted >= v_campaign.creators_wanted then
    raise exception 'Campaign creator slots are full';
  end if;

  -- Rate limit: max 20 applications / hour
  select count(*) into v_recent
  from public.bounty_applications
  where creator_id = v_uid
    and created_at > now() - interval '1 hour';
  if v_recent >= 20 then
    raise exception 'Application rate limit exceeded';
  end if;

  perform public.fv_ensure_creator_profile();

  select * into v_app
  from public.bounty_applications
  where campaign_id = p_campaign_id and creator_id = v_uid;

  if found then
    if v_app.status in ('withdrawn', 'declined') then
      update public.bounty_applications
      set status = 'applied',
          message = p_message,
          requirements_version = v_campaign.current_requirements_version,
          withdrawn_at = null,
          declined_at = null,
          updated_at = now()
      where id = v_app.id
      returning * into v_app;
      return v_app;
    end if;
    raise exception 'Duplicate application';
  end if;

  insert into public.bounty_applications (
    campaign_id, creator_id, status, requirements_version, message
  ) values (
    p_campaign_id, v_uid, 'applied', v_campaign.current_requirements_version, p_message
  )
  returning * into v_app;

  return v_app;
end;
$$;

revoke all on function public.fv_apply_to_bounty(uuid, text) from public;
grant execute on function public.fv_apply_to_bounty(uuid, text) to authenticated, service_role;

create or replace function public.fv_withdraw_bounty_application(p_application_id uuid)
returns public.bounty_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_app public.bounty_applications;
begin
  select * into v_app from public.bounty_applications where id = p_application_id;
  if not found or v_app.creator_id <> v_uid then
    raise exception 'Application not found';
  end if;
  if v_app.status <> 'applied' then
    raise exception 'Only applied applications can be withdrawn';
  end if;

  update public.bounty_applications
  set status = 'withdrawn',
      withdrawn_at = now(),
      updated_at = now()
  where id = p_application_id
  returning * into v_app;

  return v_app;
end;
$$;

revoke all on function public.fv_withdraw_bounty_application(uuid) from public;
grant execute on function public.fv_withdraw_bounty_application(uuid) to authenticated, service_role;

create or replace function public.fv_accept_bounty_application(p_application_id uuid)
returns public.bounty_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_app public.bounty_applications;
  v_campaign public.bounty_campaigns;
begin
  select * into v_app from public.bounty_applications where id = p_application_id for update;
  if not found then
    raise exception 'Application not found';
  end if;

  select * into v_campaign from public.bounty_campaigns where id = v_app.campaign_id for update;
  if not (
    v_campaign.created_by = v_uid
    or (v_campaign.business_id is not null and public.fv_owns_business(v_campaign.business_id, v_uid))
    or public.is_firstvue_admin()
  ) then
    raise exception 'Not authorized';
  end if;

  if v_app.status <> 'applied' then
    raise exception 'Application is not pending';
  end if;
  if v_campaign.creators_accepted >= v_campaign.creators_wanted then
    raise exception 'No creator slots remaining';
  end if;

  -- Lock current requirements version on first acceptance.
  update public.bounty_requirement_versions
  set locked_at = coalesce(locked_at, now()),
      locked_reason = coalesce(locked_reason, 'first_creator_acceptance')
  where campaign_id = v_campaign.id
    and version = v_campaign.current_requirements_version
    and locked_at is null;

  update public.bounty_applications
  set status = 'accepted',
      accepted_at = now(),
      requirements_version = v_campaign.current_requirements_version,
      updated_at = now()
  where id = p_application_id
  returning * into v_app;

  update public.bounty_campaigns
  set creators_accepted = creators_accepted + 1,
      updated_at = now()
  where id = v_campaign.id;

  insert into public.activity_notifications (user_id, type, title, body, payload)
  values (
    v_app.creator_id,
    'bounty_application_accepted',
    'Application accepted',
    'You were accepted for a VUE Bounty.',
    jsonb_build_object('campaign_id', v_campaign.id, 'application_id', v_app.id)
  );

  return v_app;
end;
$$;

revoke all on function public.fv_accept_bounty_application(uuid) from public;
grant execute on function public.fv_accept_bounty_application(uuid) to authenticated, service_role;

create or replace function public.fv_get_creator_earnings_summary(p_profile_id uuid default auth.uid())
returns table (
  available_cents integer,
  pending_cents integer,
  lifetime_cents integer
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_profile_id <> auth.uid() and not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;

  return query
  select
    coalesce(b.available_cents, 0),
    coalesce(b.pending_cents, 0),
    coalesce(b.lifetime_cents, 0)
  from (select p_profile_id as profile_id) p
  left join public.creator_earnings_balances b on b.profile_id = p.profile_id;
end;
$$;

revoke all on function public.fv_get_creator_earnings_summary(uuid) from public;
grant execute on function public.fv_get_creator_earnings_summary(uuid) to authenticated, service_role;

create or replace function public.fv_list_nearby_bounties(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns setof public.bounty_campaigns
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return query
  select c.*
  from public.bounty_campaigns c
  where c.status = 'active'
  order by
    case
      when p_latitude is null or p_longitude is null or c.latitude is null or c.longitude is null
      then 1
      else 0
    end,
    case
      when p_latitude is null or p_longitude is null or c.latitude is null or c.longitude is null
      then 0
      else (c.latitude - p_latitude) * (c.latitude - p_latitude)
         + (c.longitude - p_longitude) * (c.longitude - p_longitude)
    end,
    c.created_at desc
  limit greatest(1, least(coalesce(p_limit, 20), 50))
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke all on function public.fv_list_nearby_bounties(double precision, double precision, integer, integer) from public;
grant execute on function public.fv_list_nearby_bounties(double precision, double precision, integer, integer)
  to anon, authenticated, service_role;

create or replace function public.fv_is_monetization_flag_enabled(p_flag text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select enabled from public.monetization_feature_flags where flag_key = p_flag),
    false
  );
$$;

revoke all on function public.fv_is_monetization_flag_enabled(text) from public;
grant execute on function public.fv_is_monetization_flag_enabled(text)
  to anon, authenticated, service_role;

-- Admin financial overview (read-only aggregates)
create or replace function public.fv_admin_financial_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.is_firstvue_admin() then
    raise exception 'Not authorized';
  end if;

  return jsonb_build_object(
    'campaigns_by_status', (
      select coalesce(jsonb_object_agg(status, cnt), '{}'::jsonb)
      from (
        select status, count(*)::int as cnt from public.bounty_campaigns group by status
      ) s
    ),
    'open_disputes', (
      select count(*)::int from public.campaign_disputes where status in ('open', 'under_review')
    ),
    'risk_review_count', (
      select count(*)::int from public.account_risk_states where risk_state <> 'normal'
    ),
    'ledger_entry_count', (
      select count(*)::int from public.financial_ledger_entries
    ),
    'pending_payouts', (
      select count(*)::int from public.payout_records where status in ('pending', 'processing')
    )
  );
end;
$$;

revoke all on function public.fv_admin_financial_overview() from public;
grant execute on function public.fv_admin_financial_overview() to authenticated, service_role;
