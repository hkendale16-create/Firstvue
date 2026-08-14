-- Profile media captions + safer Explore directory ordering.
-- Safe to re-run.

alter table public.profile_media
  add column if not exists caption text;

-- Expose created_at on public cards so Explore can show newest people first
-- (needed for freshly seeded demo profiles to appear without scrolling luck).
drop view if exists public.profile_public_cards;

create view public.profile_public_cards
with (security_invoker = false, security_barrier = true) as
select
  p.id,
  p.display_name,
  p.username,
  coalesce(p.is_private, false) as is_private,
  coalesce(p.profile_visibility, 'public') as profile_visibility,
  p.created_at
from public.profiles p;

comment on view public.profile_public_cards is
  'Safe directory cards for feeds/search. Includes created_at for ordering. No phone, birthday, coordinates, postal_code, field_visibility, or account_type.';

revoke all on public.profile_public_cards from public;
grant select on public.profile_public_cards to anon, authenticated;
