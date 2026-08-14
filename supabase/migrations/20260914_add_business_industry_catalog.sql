-- Additive industry catalog rows for the Add Business redesign.
-- Idempotent: upserts by slug without rewriting existing business rows.

alter table public.industries
  add column if not exists template_key text,
  add column if not exists parent_slug text,
  add column if not exists sort_order integer not null default 100;

insert into public.industries (name, slug, template_key, parent_slug, sort_order, is_active)
values
  ('Makeup Artist', 'makeup-artist', 'beauty', 'beauty-grooming', 15, true),
  ('Hair Salon', 'hair-salon', 'beauty', 'beauty-grooming', 16, true),
  ('Consulting', 'consulting', 'professional', 'professional-services', 71, true),
  ('Home Services', 'home-services', 'professional', null, 74, true),
  ('Auto Services', 'auto-services', 'professional', 'home-services', 75, true),
  ('Cleaning', 'cleaning-services', 'professional', 'home-services', 76, true),
  ('Health & Fitness', 'health-fitness', 'activity', null, 78, true),
  ('Fitness Studio', 'fitness-studio', 'activity', 'health-fitness', 79, true),
  ('Gym', 'gym', 'activity', 'health-fitness', 80, true),
  ('Entertainment', 'entertainment', 'event', null, 82, true),
  ('Venue', 'venue', 'event', 'entertainment', 83, true),
  ('Boutique', 'boutique', 'retail', 'retail', 85, true)
on conflict (slug) do update
  set template_key = excluded.template_key,
      parent_slug = excluded.parent_slug,
      name = excluded.name,
      sort_order = excluded.sort_order,
      is_active = true;

insert into public.categories (industry_id, name, slug, is_active)
select i.id, i.name, i.slug, true
from public.industries i
where not exists (
  select 1 from public.categories c where c.slug = i.slug
)
on conflict (slug) do nothing;
