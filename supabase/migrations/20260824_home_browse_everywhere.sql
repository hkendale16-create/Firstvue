-- Add browse_everywhere flag for home location picker.
alter table public.user_preferences
  add column if not exists browse_everywhere boolean not null default false;
