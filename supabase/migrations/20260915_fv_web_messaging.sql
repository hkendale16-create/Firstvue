-- FirstVue unified web messaging (additive).
-- Does not drop or rewrite legacy direct_message_* tables.
-- Ciphertext only in message bodies; private keys never stored here.

-- ---------------------------------------------------------------------------
-- Helpers (boolean-only security definer; no recursive policies)
-- ---------------------------------------------------------------------------

create or replace function public.fv_msg_has_messaging_permission(
  p_business_id uuid,
  p_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    p_profile_id is not null
    and (
      exists (
        select 1 from public.businesses b
        where b.id = p_business_id
          and b.created_by = p_profile_id
      )
      or exists (
        select 1 from public.business_memberships m
        where m.business_id = p_business_id
          and m.profile_id = p_profile_id
          and m.role in ('owner', 'manager', 'moderator')
      )
    ),
    false
  );
$$;

revoke all on function public.fv_msg_has_messaging_permission(uuid, uuid) from public;
grant execute on function public.fv_msg_has_messaging_permission(uuid, uuid) to authenticated;

create or replace function public.fv_msg_is_under_13(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select birthday is not null
        and birthday > (current_date - interval '13 years')
      from public.profiles
      where id = p_profile_id
    ),
    false
  );
$$;

revoke all on function public.fv_msg_is_under_13(uuid) from public;
grant execute on function public.fv_msg_is_under_13(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Devices, recovery, blocks, parental
-- ---------------------------------------------------------------------------

create table if not exists public.fv_msg_devices (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  device_label text,
  public_key bytea not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index if not exists fv_msg_devices_active_key_idx
  on public.fv_msg_devices (profile_id, public_key)
  where revoked_at is null;

create table if not exists public.fv_msg_recovery (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  kdf text not null default 'pbkdf2-sha256',
  kdf_salt bytea not null,
  kdf_params jsonb not null default '{}'::jsonb,
  wrapped_private_key bytea not null,
  wrap_nonce bytea not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.fv_msg_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.fv_msg_parental (
  child_id uuid primary key references public.profiles(id) on delete cascade,
  parent_id uuid not null references public.profiles(id) on delete cascade,
  supervision_level text not null default 'contacts_only'
    check (supervision_level in (
      'contacts_only', 'content_visible', 'full'
    )),
  allow_calls boolean not null default false,
  allow_downloads boolean not null default false,
  allow_media boolean not null default false,
  allow_location boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.fv_msg_approved_contacts (
  child_id uuid not null references public.profiles(id) on delete cascade,
  contact_id uuid not null references public.profiles(id) on delete cascade,
  approved_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (child_id, contact_id)
);

create or replace function public.fv_msg_contact_allowed(
  p_a uuid,
  p_b uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    not exists (
      select 1 from public.fv_msg_blocks
      where (blocker_id = p_a and blocked_id = p_b)
         or (blocker_id = p_b and blocked_id = p_a)
    )
    and (
      not public.fv_msg_is_under_13(p_a)
      or exists (
        select 1 from public.fv_msg_approved_contacts c
        where c.child_id = p_a and c.contact_id = p_b
      )
    )
    and (
      not public.fv_msg_is_under_13(p_b)
      or exists (
        select 1 from public.fv_msg_approved_contacts c
        where c.child_id = p_b and c.contact_id = p_a
      )
    );
$$;

revoke all on function public.fv_msg_contact_allowed(uuid, uuid) from public;
grant execute on function public.fv_msg_contact_allowed(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Conversations
-- ---------------------------------------------------------------------------

create table if not exists public.fv_msg_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in (
    'direct', 'group', 'community', 'entity_inbox', 'event'
  )),
  entity_kind text check (entity_kind in (
    'business', 'professional', 'community', 'event', 'group'
  )),
  entity_id uuid,
  event_id uuid references public.community_events(id) on delete set null,
  community_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  title text,
  inbox_status text not null default 'new'
    check (inbox_status in (
      'new', 'assigned', 'waiting_customer', 'waiting_team',
      'resolved', 'closed', 'spam'
    )),
  request_state text not null default 'none'
    check (request_state in ('none', 'pending', 'accepted', 'deleted')),
  protocol text not null default 'envelope-v1',
  current_epoch integer not null default 1,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  legacy_thread_id uuid unique
    references public.direct_message_threads(id) on delete set null
);

create index if not exists fv_msg_conversations_kind_last_idx
  on public.fv_msg_conversations (kind, last_message_at desc);
create index if not exists fv_msg_conversations_entity_idx
  on public.fv_msg_conversations (entity_kind, entity_id, last_message_at desc)
  where entity_id is not null;
create index if not exists fv_msg_conversations_event_idx
  on public.fv_msg_conversations (event_id)
  where event_id is not null;
create index if not exists fv_msg_conversations_status_idx
  on public.fv_msg_conversations (inbox_status)
  where kind = 'entity_inbox';

create table if not exists public.fv_msg_members (
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  identity_kind text not null default 'personal'
    check (identity_kind in (
      'personal', 'business', 'professional', 'community', 'event'
    )),
  identity_id uuid,
  role text not null default 'member'
    check (role in (
      'member', 'customer', 'host', 'moderator', 'assignee', 'owner'
    )),
  can_send boolean not null default true,
  muted_until timestamptz,
  last_read_at timestamptz,
  last_read_seq bigint,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (conversation_id, profile_id)
);

create index if not exists fv_msg_members_profile_idx
  on public.fv_msg_members (profile_id, left_at, conversation_id);
create index if not exists fv_msg_members_unread_idx
  on public.fv_msg_members (profile_id)
  where left_at is null;

create or replace function public.fv_msg_is_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.fv_msg_members m
    where m.conversation_id = p_conversation_id
      and m.profile_id = auth.uid()
      and m.left_at is null
  );
$$;

revoke all on function public.fv_msg_is_member(uuid) from public;
grant execute on function public.fv_msg_is_member(uuid) to authenticated;

create or replace function public.fv_msg_can_access(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.fv_msg_conversations c
    where c.id = p_conversation_id
      and (
        public.fv_msg_is_member(c.id)
        or (
          c.kind = 'entity_inbox'
          and c.entity_kind = 'business'
          and public.fv_msg_has_messaging_permission(c.entity_id)
        )
      )
  );
$$;

revoke all on function public.fv_msg_can_access(uuid) from public;
grant execute on function public.fv_msg_can_access(uuid) to authenticated;

create table if not exists public.fv_msg_key_envelopes (
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  epoch integer not null,
  device_id uuid not null references public.fv_msg_devices(id) on delete cascade,
  wrapped_key bytea not null,
  wrap_nonce bytea not null,
  sender_public_key bytea,
  algorithm text not null default 'x25519-hkdf-aes256gcm',
  created_at timestamptz not null default now(),
  primary key (conversation_id, epoch, device_id)
);

create table if not exists public.fv_msg_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  sender_identity_kind text not null default 'personal',
  sender_identity_id uuid,
  epoch integer not null default 1,
  seq bigint not null,
  ciphertext bytea not null,
  nonce bytea not null,
  content_type text not null default 'text'
    check (content_type in (
      'text', 'image', 'video', 'audio', 'voice', 'file', 'gif',
      'sticker', 'contact', 'location', 'event_card', 'post_card',
      'profile_card', 'plan', 'system', 'call'
    )),
  reply_to_id uuid,
  channel_id uuid,
  client_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  edited_at timestamptz,
  deleted_for_everyone_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists fv_msg_messages_seq_idx
  on public.fv_msg_messages (conversation_id, seq);
create unique index if not exists fv_msg_messages_client_idx
  on public.fv_msg_messages (conversation_id, sender_id, client_id)
  where client_id is not null;
create index if not exists fv_msg_messages_created_idx
  on public.fv_msg_messages (conversation_id, created_at desc);

create table if not exists public.fv_msg_revisions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null
    references public.fv_msg_messages(id) on delete cascade,
  ciphertext bytea not null,
  nonce bytea not null,
  created_at timestamptz not null default now()
);

create table if not exists public.fv_msg_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null
    references public.fv_msg_messages(id) on delete cascade,
  storage_path text not null,
  wrapped_content_key bytea not null,
  wrap_nonce bytea not null,
  byte_size integer not null,
  mime_hint text,
  width integer,
  height integer,
  duration_ms integer
);

create table if not exists public.fv_msg_reactions (
  message_id uuid not null
    references public.fv_msg_messages(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  ciphertext bytea not null,
  nonce bytea not null,
  created_at timestamptz not null default now(),
  primary key (message_id, profile_id)
);

create table if not exists public.fv_msg_local_deletes (
  message_id uuid not null
    references public.fv_msg_messages(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (message_id, profile_id)
);

create table if not exists public.fv_msg_internal_notes (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  ciphertext bytea not null,
  nonce bytea not null,
  created_at timestamptz not null default now()
);

create table if not exists public.fv_msg_assignments (
  conversation_id uuid primary key
    references public.fv_msg_conversations(id) on delete cascade,
  assignee_id uuid references public.profiles(id) on delete set null,
  assigned_by uuid references public.profiles(id),
  assigned_at timestamptz not null default now()
);

create table if not exists public.fv_msg_customer_tags (
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  tag text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  primary key (conversation_id, tag)
);

create table if not exists public.fv_msg_saved_replies (
  id uuid primary key default gen_random_uuid(),
  entity_id uuid not null,
  entity_kind text not null default 'business',
  title text not null,
  ciphertext bytea not null,
  nonce bytea not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.fv_msg_event_settings (
  event_id uuid primary key
    references public.community_events(id) on delete cascade,
  conversation_id uuid references public.fv_msg_conversations(id),
  chat_enabled boolean not null default false,
  who_may_enter text not null default 'attendees'
    check (who_may_enter in ('attendees', 'invited', 'followers')),
  attendees_visible boolean not null default true,
  activate_before_event boolean not null default false,
  archive_after interval,
  archived_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.fv_msg_event_channels (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  kind text not null check (kind in ('announcements', 'attendee', 'topic')),
  slug text not null,
  title text not null,
  created_at timestamptz not null default now(),
  unique (conversation_id, slug)
);

alter table public.fv_msg_messages
  drop constraint if exists fv_msg_messages_channel_fk;
alter table public.fv_msg_messages
  add constraint fv_msg_messages_channel_fk
  foreign key (channel_id) references public.fv_msg_event_channels(id)
  on delete set null;

create table if not exists public.fv_msg_event_plans (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  created_by uuid not null references public.profiles(id),
  title_ciphertext bytea not null,
  title_nonce bytea not null,
  area_ciphertext bytea,
  area_nonce bytea,
  meet_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.fv_msg_event_plan_members (
  plan_id uuid not null
    references public.fv_msg_event_plans(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (plan_id, profile_id)
);

create table if not exists public.fv_msg_notification_prefs (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  identity_kind text not null default 'personal',
  identity_id uuid not null default '00000000-0000-0000-0000-000000000000',
  quiet_hours_start time,
  quiet_hours_end time,
  mentions boolean not null default true,
  event_safety boolean not null default true,
  assigned_priority boolean not null default true,
  primary key (profile_id, identity_kind, identity_id)
);

create table if not exists public.fv_msg_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  selected_message_ids uuid[] not null,
  bundle_ciphertext bytea not null,
  bundle_nonce bytea not null,
  context text,
  created_at timestamptz not null default now()
);

create table if not exists public.fv_msg_calls (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  caller_id uuid not null references public.profiles(id),
  callee_id uuid not null references public.profiles(id),
  kind text not null check (kind in ('voice', 'video')),
  state text not null default 'ringing'
    check (state in (
      'ringing', 'accepted', 'declined', 'ended', 'missed', 'failed'
    )),
  offer jsonb,
  answer jsonb,
  ice jsonb not null default '[]'::jsonb,
  started_at timestamptz not null default now(),
  ended_at timestamptz
);

create table if not exists public.fv_msg_migration (
  legacy_thread_id uuid primary key
    references public.direct_message_threads(id) on delete cascade,
  conversation_id uuid references public.fv_msg_conversations(id),
  status text not null default 'pending'
    check (status in (
      'pending', 'in_progress', 'encrypted', 'failed', 'skipped'
    )),
  migrated_count integer not null default 0,
  error text,
  updated_at timestamptz not null default now()
);

create table if not exists public.fv_msg_moderator_keys (
  id uuid primary key default gen_random_uuid(),
  public_key bytea not null,
  label text not null default 'abuse-reports',
  created_at timestamptz not null default now(),
  retired_at timestamptz
);

create table if not exists public.fv_msg_audit (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.fv_msg_conversations(id) on delete cascade,
  actor_id uuid not null references public.profiles(id),
  action text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists fv_msg_audit_conv_idx
  on public.fv_msg_audit (conversation_id, created_at desc);

create table if not exists public.fv_msg_indicator_prefs (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  show_online boolean not null default true,
  show_last_active boolean not null default true,
  show_typing boolean not null default true,
  show_delivered boolean not null default true,
  show_read boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.fv_msg_rate_events (
  id bigserial primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  created_at timestamptz not null default now()
);

create index if not exists fv_msg_rate_events_idx
  on public.fv_msg_rate_events (profile_id, kind, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.fv_msg_devices enable row level security;
alter table public.fv_msg_recovery enable row level security;
alter table public.fv_msg_blocks enable row level security;
alter table public.fv_msg_parental enable row level security;
alter table public.fv_msg_approved_contacts enable row level security;
alter table public.fv_msg_conversations enable row level security;
alter table public.fv_msg_members enable row level security;
alter table public.fv_msg_key_envelopes enable row level security;
alter table public.fv_msg_messages enable row level security;
alter table public.fv_msg_revisions enable row level security;
alter table public.fv_msg_attachments enable row level security;
alter table public.fv_msg_reactions enable row level security;
alter table public.fv_msg_local_deletes enable row level security;
alter table public.fv_msg_internal_notes enable row level security;
alter table public.fv_msg_assignments enable row level security;
alter table public.fv_msg_customer_tags enable row level security;
alter table public.fv_msg_saved_replies enable row level security;
alter table public.fv_msg_event_settings enable row level security;
alter table public.fv_msg_event_channels enable row level security;
alter table public.fv_msg_event_plans enable row level security;
alter table public.fv_msg_event_plan_members enable row level security;
alter table public.fv_msg_notification_prefs enable row level security;
alter table public.fv_msg_reports enable row level security;
alter table public.fv_msg_calls enable row level security;
alter table public.fv_msg_migration enable row level security;
alter table public.fv_msg_moderator_keys enable row level security;
alter table public.fv_msg_audit enable row level security;
alter table public.fv_msg_indicator_prefs enable row level security;
alter table public.fv_msg_rate_events enable row level security;

drop policy if exists "Users manage own devices" on public.fv_msg_devices;
create policy "Users manage own devices"
  on public.fv_msg_devices for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users read peer device keys" on public.fv_msg_devices;
create policy "Users read peer device keys"
  on public.fv_msg_devices for select to authenticated
  using (revoked_at is null);

drop policy if exists "Users manage own recovery" on public.fv_msg_recovery;
create policy "Users manage own recovery"
  on public.fv_msg_recovery for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users manage own blocks" on public.fv_msg_blocks;
create policy "Users manage own blocks"
  on public.fv_msg_blocks for all to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

drop policy if exists "Parents manage parental rows" on public.fv_msg_parental;
create policy "Parents manage parental rows"
  on public.fv_msg_parental for all to authenticated
  using (parent_id = auth.uid() or child_id = auth.uid())
  with check (parent_id = auth.uid());

drop policy if exists "Parents manage approved contacts" on public.fv_msg_approved_contacts;
create policy "Parents manage approved contacts"
  on public.fv_msg_approved_contacts for all to authenticated
  using (
    approved_by = auth.uid()
    or child_id = auth.uid()
    or exists (
      select 1 from public.fv_msg_parental p
      where p.child_id = fv_msg_approved_contacts.child_id
        and p.parent_id = auth.uid()
    )
  )
  with check (
    approved_by = auth.uid()
    and exists (
      select 1 from public.fv_msg_parental p
      where p.child_id = fv_msg_approved_contacts.child_id
        and p.parent_id = auth.uid()
    )
  );

drop policy if exists "Members read conversations" on public.fv_msg_conversations;
create policy "Members read conversations"
  on public.fv_msg_conversations for select to authenticated
  using (public.fv_msg_can_access(id));

drop policy if exists "Users create conversations" on public.fv_msg_conversations;
create policy "Users create conversations"
  on public.fv_msg_conversations for insert to authenticated
  with check (created_by is null or created_by = auth.uid());

drop policy if exists "Members update conversations" on public.fv_msg_conversations;
create policy "Members update conversations"
  on public.fv_msg_conversations for update to authenticated
  using (public.fv_msg_can_access(id));

drop policy if exists "Members read membership" on public.fv_msg_members;
create policy "Members read membership"
  on public.fv_msg_members for select to authenticated
  using (public.fv_msg_can_access(conversation_id));

drop policy if exists "Users insert self as member" on public.fv_msg_members;
create policy "Users insert self as member"
  on public.fv_msg_members for insert to authenticated
  with check (
    profile_id = auth.uid()
    and role in ('member', 'customer')
  );

drop policy if exists "Staff insert entity members" on public.fv_msg_members;
create policy "Staff insert entity members"
  on public.fv_msg_members for insert to authenticated
  with check (
    exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and c.entity_kind = 'business'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Members update self membership" on public.fv_msg_members;
create policy "Members update self membership"
  on public.fv_msg_members for update to authenticated
  using (profile_id = auth.uid() or public.fv_msg_can_access(conversation_id));

drop policy if exists "Members read envelopes" on public.fv_msg_key_envelopes;
create policy "Members read envelopes"
  on public.fv_msg_key_envelopes for select to authenticated
  using (
    public.fv_msg_can_access(conversation_id)
    and exists (
      select 1 from public.fv_msg_devices d
      where d.id = device_id
        and (d.profile_id = auth.uid() or public.fv_msg_can_access(conversation_id))
    )
  );

drop policy if exists "Members write envelopes" on public.fv_msg_key_envelopes;
create policy "Members write envelopes"
  on public.fv_msg_key_envelopes for insert to authenticated
  with check (public.fv_msg_can_access(conversation_id));

drop policy if exists "Members read messages" on public.fv_msg_messages;
create policy "Members read messages"
  on public.fv_msg_messages for select to authenticated
  using (public.fv_msg_can_access(conversation_id));

drop policy if exists "Members send messages" on public.fv_msg_messages;
create policy "Members send messages"
  on public.fv_msg_messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.fv_msg_can_access(conversation_id)
    and exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.archived_at is null
        and c.request_state <> 'deleted'
    )
  );

drop policy if exists "Senders edit own messages" on public.fv_msg_messages;
create policy "Senders edit own messages"
  on public.fv_msg_messages for update to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

drop policy if exists "Members read revisions" on public.fv_msg_revisions;
create policy "Members read revisions"
  on public.fv_msg_revisions for select to authenticated
  using (
    exists (
      select 1 from public.fv_msg_messages m
      where m.id = message_id
        and public.fv_msg_can_access(m.conversation_id)
    )
  );

drop policy if exists "Senders insert revisions" on public.fv_msg_revisions;
create policy "Senders insert revisions"
  on public.fv_msg_revisions for insert to authenticated
  with check (
    exists (
      select 1 from public.fv_msg_messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
    )
  );

drop policy if exists "Members read attachments" on public.fv_msg_attachments;
create policy "Members read attachments"
  on public.fv_msg_attachments for select to authenticated
  using (
    exists (
      select 1 from public.fv_msg_messages m
      where m.id = message_id
        and public.fv_msg_can_access(m.conversation_id)
    )
  );

drop policy if exists "Senders insert attachments" on public.fv_msg_attachments;
create policy "Senders insert attachments"
  on public.fv_msg_attachments for insert to authenticated
  with check (
    exists (
      select 1 from public.fv_msg_messages m
      where m.id = message_id
        and m.sender_id = auth.uid()
    )
  );

drop policy if exists "Members read reactions" on public.fv_msg_reactions;
create policy "Members read reactions"
  on public.fv_msg_reactions for select to authenticated
  using (
    exists (
      select 1 from public.fv_msg_messages m
      where m.id = message_id
        and public.fv_msg_can_access(m.conversation_id)
    )
  );

drop policy if exists "Members write reactions" on public.fv_msg_reactions;
create policy "Members write reactions"
  on public.fv_msg_reactions for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users manage local deletes" on public.fv_msg_local_deletes;
create policy "Users manage local deletes"
  on public.fv_msg_local_deletes for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Staff read internal notes" on public.fv_msg_internal_notes;
create policy "Staff read internal notes"
  on public.fv_msg_internal_notes for select to authenticated
  using (
    exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and c.entity_kind = 'business'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Staff write internal notes" on public.fv_msg_internal_notes;
create policy "Staff write internal notes"
  on public.fv_msg_internal_notes for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and c.entity_kind = 'business'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Staff manage assignments" on public.fv_msg_assignments;
create policy "Staff manage assignments"
  on public.fv_msg_assignments for all to authenticated
  using (
    exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  )
  with check (
    exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Staff manage tags" on public.fv_msg_customer_tags;
create policy "Staff manage tags"
  on public.fv_msg_customer_tags for all to authenticated
  using (
    exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  )
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Staff manage saved replies" on public.fv_msg_saved_replies;
create policy "Staff manage saved replies"
  on public.fv_msg_saved_replies for all to authenticated
  using (
    entity_kind = 'business'
    and public.fv_msg_has_messaging_permission(entity_id)
  )
  with check (
    created_by = auth.uid()
    and public.fv_msg_has_messaging_permission(entity_id)
  );

drop policy if exists "Hosts manage event settings" on public.fv_msg_event_settings;
create policy "Hosts manage event settings"
  on public.fv_msg_event_settings for all to authenticated
  using (
    exists (
      select 1 from public.community_events e
      where e.id = event_id
        and e.organizer_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.community_events e
      where e.id = event_id
        and e.organizer_id = auth.uid()
    )
  );

drop policy if exists "Members read event settings" on public.fv_msg_event_settings;
create policy "Members read event settings"
  on public.fv_msg_event_settings for select to authenticated
  using (
    conversation_id is not null
    and public.fv_msg_can_access(conversation_id)
  );

drop policy if exists "Members read event channels" on public.fv_msg_event_channels;
create policy "Members read event channels"
  on public.fv_msg_event_channels for select to authenticated
  using (public.fv_msg_can_access(conversation_id));

drop policy if exists "Hosts write event channels" on public.fv_msg_event_channels;
create policy "Hosts write event channels"
  on public.fv_msg_event_channels for insert to authenticated
  with check (
    exists (
      select 1 from public.fv_msg_members m
      where m.conversation_id = fv_msg_event_channels.conversation_id
        and m.profile_id = auth.uid()
        and m.role in ('host', 'moderator')
        and m.left_at is null
    )
  );

drop policy if exists "Members read plans" on public.fv_msg_event_plans;
create policy "Members read plans"
  on public.fv_msg_event_plans for select to authenticated
  using (public.fv_msg_can_access(conversation_id));

drop policy if exists "Members create plans" on public.fv_msg_event_plans;
create policy "Members create plans"
  on public.fv_msg_event_plans for insert to authenticated
  with check (
    created_by = auth.uid()
    and public.fv_msg_can_access(conversation_id)
  );

drop policy if exists "Members manage plan membership" on public.fv_msg_event_plan_members;
create policy "Members manage plan membership"
  on public.fv_msg_event_plan_members for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users manage notification prefs" on public.fv_msg_notification_prefs;
create policy "Users manage notification prefs"
  on public.fv_msg_notification_prefs for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users insert reports" on public.fv_msg_reports;
create policy "Users insert reports"
  on public.fv_msg_reports for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and public.fv_msg_can_access(conversation_id)
  );

drop policy if exists "Users read own reports" on public.fv_msg_reports;
create policy "Users read own reports"
  on public.fv_msg_reports for select to authenticated
  using (reporter_id = auth.uid());

drop policy if exists "Participants manage calls" on public.fv_msg_calls;
create policy "Participants manage calls"
  on public.fv_msg_calls for all to authenticated
  using (caller_id = auth.uid() or callee_id = auth.uid())
  with check (caller_id = auth.uid() or callee_id = auth.uid());

drop policy if exists "Users read own migration rows" on public.fv_msg_migration;
create policy "Users read own migration rows"
  on public.fv_msg_migration for select to authenticated
  using (
    exists (
      select 1 from public.direct_message_threads t
      where t.id = legacy_thread_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  );

drop policy if exists "Users write own migration rows" on public.fv_msg_migration;
create policy "Users write own migration rows"
  on public.fv_msg_migration for all to authenticated
  using (
    exists (
      select 1 from public.direct_message_threads t
      where t.id = legacy_thread_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.direct_message_threads t
      where t.id = legacy_thread_id
        and (t.participant_a = auth.uid() or t.participant_b = auth.uid())
    )
  );

drop policy if exists "Authenticated read moderator public keys" on public.fv_msg_moderator_keys;
create policy "Authenticated read moderator public keys"
  on public.fv_msg_moderator_keys for select to authenticated
  using (retired_at is null);

drop policy if exists "Staff read audit" on public.fv_msg_audit;
create policy "Staff read audit"
  on public.fv_msg_audit for select to authenticated
  using (
    exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Staff write audit" on public.fv_msg_audit;
create policy "Staff write audit"
  on public.fv_msg_audit for insert to authenticated
  with check (
    actor_id = auth.uid()
    and exists (
      select 1 from public.fv_msg_conversations c
      where c.id = conversation_id
        and c.kind = 'entity_inbox'
        and public.fv_msg_has_messaging_permission(c.entity_id)
    )
  );

drop policy if exists "Users manage indicator prefs" on public.fv_msg_indicator_prefs;
create policy "Users manage indicator prefs"
  on public.fv_msg_indicator_prefs for all to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

drop policy if exists "Users insert own rate events" on public.fv_msg_rate_events;
create policy "Users insert own rate events"
  on public.fv_msg_rate_events for insert to authenticated
  with check (profile_id = auth.uid());

drop policy if exists "Users read own rate events" on public.fv_msg_rate_events;
create policy "Users read own rate events"
  on public.fv_msg_rate_events for select to authenticated
  using (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------

create or replace function public.fv_msg_open_direct(
  p_other uuid,
  p_identity_kind text default 'personal',
  p_identity_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_existing uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if p_other = auth.uid() then
    raise exception 'Cannot message yourself';
  end if;
  if not public.fv_msg_contact_allowed(auth.uid(), p_other) then
    raise exception 'Contact is not allowed';
  end if;

  select c.id into v_existing
  from public.fv_msg_conversations c
  join public.fv_msg_members a
    on a.conversation_id = c.id and a.profile_id = auth.uid() and a.left_at is null
  join public.fv_msg_members b
    on b.conversation_id = c.id and b.profile_id = p_other and b.left_at is null
  where c.kind = 'direct'
  limit 1;
  if v_existing is not null then
    return v_existing;
  end if;

  v_id := gen_random_uuid();
  insert into public.fv_msg_conversations (id, kind, request_state)
  values (v_id, 'direct', 'pending');
  insert into public.fv_msg_members (
    conversation_id, profile_id, identity_kind, identity_id, role
  ) values
    (v_id, auth.uid(), coalesce(p_identity_kind, 'personal'), p_identity_id, 'member'),
    (v_id, p_other, 'personal', null, 'member');
  return v_id;
end;
$$;

revoke all on function public.fv_msg_open_direct(uuid, text, uuid) from public;
grant execute on function public.fv_msg_open_direct(uuid, text, uuid) to authenticated;

create or replace function public.fv_msg_enable_event_chat(p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_host uuid;
  v_cid uuid;
begin
  if v_uid is null then
    raise exception 'Not signed in';
  end if;
  select e.organizer_id into v_host
  from public.community_events e
  where e.id = p_event_id;
  if v_host is null then
    raise exception 'Event not found';
  end if;
  if v_host is distinct from v_uid then
    raise exception 'Only the host can enable event chat';
  end if;
  select c.id into v_cid
  from public.fv_msg_conversations c
  where c.kind = 'event' and c.event_id = p_event_id
  limit 1;
  if v_cid is not null then
    update public.fv_msg_conversations
    set archived_at = null, updated_at = now()
    where id = v_cid;
    insert into public.fv_msg_event_settings (event_id, conversation_id, chat_enabled)
    values (p_event_id, v_cid, true)
    on conflict (event_id) do update
      set chat_enabled = true, conversation_id = v_cid, archived_at = null, updated_at = now();
    return v_cid;
  end if;
  insert into public.fv_msg_conversations (kind, event_id, created_by, title)
  values ('event', p_event_id, v_uid, (select title from public.community_events where id = p_event_id))
  returning id into v_cid;
  insert into public.fv_msg_members (conversation_id, profile_id, identity_kind, role)
  values (v_cid, v_uid, 'personal', 'host')
  on conflict do nothing;
  insert into public.fv_msg_event_channels (conversation_id, slug, title, kind)
  values
    (v_cid, 'announcements', 'Announcements', 'announcements'),
    (v_cid, 'attendee', 'Attendee chat', 'attendee')
  on conflict do nothing;
  insert into public.fv_msg_event_settings (event_id, conversation_id, chat_enabled)
  values (p_event_id, v_cid, true)
  on conflict (event_id) do update
    set chat_enabled = true, conversation_id = v_cid, archived_at = null, updated_at = now();
  return v_cid;
end;
$$;

revoke all on function public.fv_msg_enable_event_chat(uuid) from public;
grant execute on function public.fv_msg_enable_event_chat(uuid) to authenticated;

create or replace function public.fv_msg_next_seq(p_conversation_id uuid)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seq bigint;
begin
  if not public.fv_msg_can_access(p_conversation_id) then
    raise exception 'Not a member';
  end if;
  select coalesce(max(seq), 0) + 1
    into v_seq
  from public.fv_msg_messages
  where conversation_id = p_conversation_id;
  return v_seq;
end;
$$;

revoke all on function public.fv_msg_next_seq(uuid) from public;
grant execute on function public.fv_msg_next_seq(uuid) to authenticated;

create or replace function public.fv_msg_unread_counts()
returns table (
  identity_kind text,
  identity_id uuid,
  unread integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    m.identity_kind,
    m.identity_id,
    count(*)::integer as unread
  from public.fv_msg_members m
  join public.fv_msg_conversations c on c.id = m.conversation_id
  join public.fv_msg_messages msg on msg.conversation_id = c.id
  where m.profile_id = auth.uid()
    and m.left_at is null
    and m.muted_until is null
    and msg.sender_id <> auth.uid()
    and msg.deleted_for_everyone_at is null
    and msg.created_at > coalesce(m.last_read_at, to_timestamp(0))
    and c.request_state <> 'deleted'
  group by m.identity_kind, m.identity_id;
$$;

revoke all on function public.fv_msg_unread_counts() from public;
grant execute on function public.fv_msg_unread_counts() to authenticated;

create or replace function public.fv_msg_mark_read(
  p_conversation_id uuid,
  p_seq bigint default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fv_msg_is_member(p_conversation_id) then
    raise exception 'Not a member';
  end if;
  update public.fv_msg_members
  set last_read_at = now(),
      last_read_seq = coalesce(p_seq, last_read_seq)
  where conversation_id = p_conversation_id
    and profile_id = auth.uid();
end;
$$;

revoke all on function public.fv_msg_mark_read(uuid, bigint) from public;
grant execute on function public.fv_msg_mark_read(uuid, bigint) to authenticated;

create or replace function public.fv_msg_open_entity_inbox(
  p_entity_id uuid,
  p_entity_kind text default 'business'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_existing uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if p_entity_kind = 'business'
     and public.fv_msg_has_messaging_permission(p_entity_id, v_uid) then
    raise exception 'Staff cannot open the customer side of this inbox';
  end if;

  select c.id into v_existing
  from public.fv_msg_conversations c
  join public.fv_msg_members m
    on m.conversation_id = c.id
   and m.profile_id = v_uid
   and m.left_at is null
  where c.kind = 'entity_inbox'
    and c.entity_id = p_entity_id
    and c.entity_kind = coalesce(p_entity_kind, 'business')
  limit 1;
  if v_existing is not null then
    return v_existing;
  end if;

  v_id := gen_random_uuid();
  insert into public.fv_msg_conversations (
    id, kind, entity_kind, entity_id, created_by, inbox_status, request_state
  ) values (
    v_id, 'entity_inbox', coalesce(p_entity_kind, 'business'), p_entity_id,
    v_uid, 'new', 'none'
  );
  insert into public.fv_msg_members (
    conversation_id, profile_id, identity_kind, role
  ) values (v_id, v_uid, 'personal', 'customer');
  return v_id;
end;
$$;

revoke all on function public.fv_msg_open_entity_inbox(uuid, text) from public;
grant execute on function public.fv_msg_open_entity_inbox(uuid, text) to authenticated;

create or replace function public.fv_msg_join_event_chat(p_event_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_cid uuid;
  v_who text;
  v_host uuid;
  v_ok boolean := false;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  select c.id, s.who_may_enter, e.organizer_id
    into v_cid, v_who, v_host
  from public.fv_msg_conversations c
  join public.community_events e on e.id = c.event_id
  left join public.fv_msg_event_settings s on s.event_id = c.event_id
  where c.kind = 'event' and c.event_id = p_event_id
  limit 1;
  if v_cid is null then
    raise exception 'Event chat is not enabled';
  end if;
  if v_host = v_uid then
    v_ok := true;
  elsif coalesce(v_who, 'attendees') = 'attendees' then
    v_ok := exists (
      select 1 from public.event_attendance a
      where a.event_id = p_event_id
        and a.profile_id = v_uid
        and a.status in ('attending', 'interested')
    );
  elsif v_who = 'followers' then
    v_ok := exists (
      select 1 from public.event_follows f
      where f.event_id = p_event_id and f.profile_id = v_uid
    );
  end if;
  if not v_ok then
    raise exception 'Not allowed to join this event conversation';
  end if;
  insert into public.fv_msg_members (conversation_id, profile_id, identity_kind, role)
  values (v_cid, v_uid, 'personal', case when v_host = v_uid then 'host' else 'member' end)
  on conflict (conversation_id, profile_id) do update
    set left_at = null;
  return v_cid;
end;
$$;

revoke all on function public.fv_msg_join_event_chat(uuid) from public;
grant execute on function public.fv_msg_join_event_chat(uuid) to authenticated;

create or replace function public.fv_msg_archive_event_chat(p_event_id uuid, p_archive boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_host uuid;
begin
  select organizer_id into v_host
  from public.community_events
  where id = p_event_id;
  if v_host is distinct from auth.uid() then
    raise exception 'Only the host can archive event chat';
  end if;
  update public.fv_msg_conversations
  set archived_at = case when p_archive then now() else null end,
      updated_at = now()
  where kind = 'event' and event_id = p_event_id;
  update public.fv_msg_event_settings
  set archived_at = case when p_archive then now() else null end,
      updated_at = now()
  where event_id = p_event_id;
end;
$$;

revoke all on function public.fv_msg_archive_event_chat(uuid, boolean) from public;
grant execute on function public.fv_msg_archive_event_chat(uuid, boolean) to authenticated;

create or replace function public.fv_msg_within_rate_limit(
  p_kind text,
  p_max integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    return false;
  end if;
  select count(*) into v_count
  from public.fv_msg_rate_events
  where profile_id = auth.uid()
    and kind = p_kind
    and created_at > now() - make_interval(secs => p_window_seconds);
  if v_count >= p_max then
    return false;
  end if;
  insert into public.fv_msg_rate_events (profile_id, kind)
  values (auth.uid(), p_kind);
  return true;
end;
$$;

revoke all on function public.fv_msg_within_rate_limit(text, integer, integer) from public;
grant execute on function public.fv_msg_within_rate_limit(text, integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: encrypted blobs only
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('fv-msg-media', 'fv-msg-media', false, 52428800)
on conflict (id) do nothing;

drop policy if exists "Members upload encrypted message media" on storage.objects;
create policy "Members upload encrypted message media"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'fv-msg-media'
    and public.fv_msg_can_access(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "Members read encrypted message media" on storage.objects;
create policy "Members read encrypted message media"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'fv-msg-media'
    and public.fv_msg_can_access(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "Members delete encrypted message media" on storage.objects;
create policy "Members delete encrypted message media"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'fv-msg-media'
    and public.fv_msg_can_access(((storage.foldername(name))[1])::uuid)
  );
