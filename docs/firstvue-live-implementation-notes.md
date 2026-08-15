# FirstVue LIVE — Implementation Notes

Last updated: 2026-08-15 (Phase 3 complete — stopped)

## Architecture

### Mode shell
- VUE tab switch → `LiveHomeShellScreen` → Right Now cards open `LiveEventDetailScreen`

### Phase 3 engagement
- Going: existing `event_attendance` (status=`attending`)
- Hot: new `event_hot_reactions` (1 row / user / event)
- I’m Here: new `event_presence` via RPCs `set_event_presence` / `clear_event_presence`
  - 4h TTL, max 12h constraint, **no GPS columns**
  - Here Now: `event_here_now_count` + non-expired rows only
- Chat: existing `EventConversationPage` + `fv_msg_*` join/enable
- Directions: external Google Maps search on `location_label`
- Share: existing `FirstVueShareSheet` / `AppConfig.eventShareUrl`
- Live VUEs: `CommunityNewsService.fetchPostsForEvent`

### Flags
- `liveEventPresenceEnabled` default **true**
- `liveEventChatEnabled` default **true**
- `liveMapEnabled` still false

## Schema / RLS (additive)
Migration: `supabase/migrations/20261001_live_event_presence_hot.sql`
- RLS ownership on insert/update/delete
- Authenticated read of active presence / hot reactions
- Security-definer RPCs enforce auth.uid() + approved event

## Files (Phase 3)
- `supabase/migrations/20261001_live_event_presence_hot.sql`
- `lib/services/live_event_engagement_service.dart`
- `lib/screens/live_event_detail_screen.dart`
- `lib/screens/live_home_shell_screen.dart` (opens detail)
- `lib/config/feature_flags.dart`
- `test/live_event_detail_test.dart`

## Visual vs refs 02/03
Matched: hero + LIVE badge, title/location, Going/Here Now/Hot stats, reaction row, Open Chat + Directions, Live VUEs shelf, Event Info.
Diffs: no fabricated view count; avatar stack deferred (ids available, full profile media join later); reactions modal not separate sheet (inline buttons).

## Tests
- analyze clean; `live_event_detail_test` + live home + vue landing pass

## Next (blocked)
- Phase 4: LIVE Map (provider analysis first)
