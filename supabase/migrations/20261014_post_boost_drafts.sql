-- Post boost drafts (no payments). Extends monetization foundation.
-- Clients may create draft/pending promotions for posts they own/manage.
-- Status active/paid transitions are server-only (no client path yet).

alter table public.monetization_products
  drop constraint if exists monetization_products_product_family_check;

alter table public.monetization_products
  add constraint monetization_products_product_family_check
  check (
    product_family in (
      'consumer_plus',
      'business_subscription',
      'business_boost',
      'event_boost',
      'post_boost',
      'bounty_campaign',
      'affiliate_program',
      'other'
    )
  );

insert into public.monetization_products (
  id, display_name, product_family, billing_period, price_cents, currency,
  platform_fee_bps, is_active, metadata
) values
  ('post_boost_local_small', 'Small Local Boost', 'post_boost', 'one_time', 500, 'usd',
   0, false, '{"reach":"local","duration_hours":24}'::jsonb),
  ('post_boost_local_large', 'Larger Local Reach', 'post_boost', 'one_time', 1500, 'usd',
   0, false, '{"reach":"local","duration_hours":72}'::jsonb),
  ('post_boost_multi_day', 'Multi-Day Promotion', 'post_boost', 'one_time', 3000, 'usd',
   0, false, '{"reach":"regional","duration_hours":168}'::jsonb)
on conflict (id) do update set
  display_name = excluded.display_name,
  product_family = excluded.product_family,
  billing_period = excluded.billing_period,
  price_cents = excluded.price_cents,
  metadata = excluded.metadata,
  updated_at = now();

create table if not exists public.post_promotions (
  id uuid primary key default gen_random_uuid(),
  news_post_id uuid not null references public.community_news_posts(id) on delete cascade,
  created_by_profile_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  product_id text not null references public.monetization_products(id),
  status text not null default 'draft' check (
    status in ('draft', 'pending', 'active', 'paused', 'completed', 'rejected')
  ),
  -- Targeting / schedule (nullable for future use; not required for drafts).
  target_city text,
  target_state text,
  radius_km integer check (radius_km is null or radius_km > 0),
  audience_category text,
  starts_at timestamptz,
  ends_at timestamptz,
  estimated_reach integer check (estimated_reach is null or estimated_reach >= 0),
  budget_cents integer check (budget_cents is null or budget_cents >= 0),
  currency text not null default 'usd',
  disclosure_label text not null default 'Promoted',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists post_promotions_post_idx
  on public.post_promotions (news_post_id, status);
create index if not exists post_promotions_creator_idx
  on public.post_promotions (created_by_profile_id, created_at desc);
create index if not exists post_promotions_active_window_idx
  on public.post_promotions (status, starts_at, ends_at)
  where status = 'active';

alter table public.post_promotions enable row level security;

-- Authorization: post author OR business owner/manager on the post's business.
create or replace function public.fv_can_manage_post_boost(p_news_post_id uuid, p_uid uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_uid is not null
    and exists (
      select 1
      from public.community_news_posts n
      where n.id = p_news_post_id
        and (
          n.author_id = p_uid
          or (
            n.business_id is not null
            and public.fv_owns_business(n.business_id, p_uid)
          )
        )
    );
$$;

revoke all on function public.fv_can_manage_post_boost(uuid, uuid) from public;
grant execute on function public.fv_can_manage_post_boost(uuid, uuid) to authenticated, service_role;

drop policy if exists "Readers see active post promotions" on public.post_promotions;
create policy "Readers see active post promotions"
  on public.post_promotions for select to anon, authenticated
  using (
    status = 'active'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  );

drop policy if exists "Creators read own post promotions" on public.post_promotions;
create policy "Creators read own post promotions"
  on public.post_promotions for select to authenticated
  using (
    created_by_profile_id = auth.uid()
    or public.fv_can_manage_post_boost(news_post_id)
    or public.is_firstvue_admin()
  );

-- No direct client INSERT/UPDATE/DELETE — use RPC only.
create or replace function public.fv_create_post_boost_draft(
  p_news_post_id uuid,
  p_product_id text,
  p_target_city text default null,
  p_target_state text default null,
  p_radius_km integer default null,
  p_audience_category text default null
)
returns public.post_promotions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_product public.monetization_products%rowtype;
  v_post public.community_news_posts%rowtype;
  v_row public.post_promotions;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if not public.fv_can_manage_post_boost(p_news_post_id, v_uid) then
    raise exception 'Not authorized to boost this post' using errcode = '42501';
  end if;

  select * into v_product
  from public.monetization_products
  where id = p_product_id
    and product_family = 'post_boost';

  if not found then
    raise exception 'Boost product not found' using errcode = 'P0002';
  end if;

  select * into v_post
  from public.community_news_posts
  where id = p_news_post_id;

  if not found then
    raise exception 'Post not found' using errcode = 'P0002';
  end if;

  insert into public.post_promotions (
    news_post_id,
    created_by_profile_id,
    business_id,
    product_id,
    status,
    target_city,
    target_state,
    radius_km,
    audience_category,
    budget_cents,
    currency,
    disclosure_label,
    metadata
  ) values (
    p_news_post_id,
    v_uid,
    v_post.business_id,
    v_product.id,
    'draft',
    nullif(trim(coalesce(p_target_city, '')), ''),
    nullif(trim(coalesce(p_target_state, '')), ''),
    p_radius_km,
    nullif(trim(coalesce(p_audience_category, '')), ''),
    v_product.price_cents,
    coalesce(v_product.currency, 'usd'),
    'Promoted',
    jsonb_build_object(
      'payment_required', true,
      'payments_enabled', false,
      'note', 'Draft only — payments not active'
    )
  )
  returning * into v_row;

  return v_row;
end;
$$;

comment on function public.fv_create_post_boost_draft(uuid, text, text, text, integer, text) is
  'Authorized users create a draft post boost. Does not charge or activate.';

revoke all on function public.fv_create_post_boost_draft(uuid, text, text, text, integer, text) from public;
grant execute on function public.fv_create_post_boost_draft(uuid, text, text, text, integer, text) to authenticated;

-- Block clients from flipping promotions to active/paid via direct updates
-- (no UPDATE policy exists; keep a trigger as defense in depth if policies change).
create or replace function public.fv_protect_post_promotion_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.status is distinct from new.status
     and new.status in ('active', 'completed')
     and not public.is_firstvue_admin()
     and current_setting('role', true) is distinct from 'service_role' then
    raise exception 'Only the server can activate or complete post promotions'
      using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_protect_post_promotion_status on public.post_promotions;
create trigger trg_protect_post_promotion_status
  before update on public.post_promotions
  for each row execute function public.fv_protect_post_promotion_status();

-- Lightweight active-boost lookup for feed ranking (no fake engagement).
create or replace function public.fv_active_post_boost_ids(p_limit integer default 50)
returns table (news_post_id uuid, product_id text, disclosure_label text)
language sql
stable
security definer
set search_path = public
as $$
  select p.news_post_id, p.product_id, p.disclosure_label
  from public.post_promotions p
  where p.status = 'active'
    and (p.starts_at is null or p.starts_at <= now())
    and (p.ends_at is null or p.ends_at >= now())
  order by p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
$$;

revoke all on function public.fv_active_post_boost_ids(integer) from public;
grant execute on function public.fv_active_post_boost_ids(integer) to authenticated, anon, service_role;
