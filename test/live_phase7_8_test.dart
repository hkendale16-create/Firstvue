import 'dart:io';

import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/services/live_business_open_service.dart';
import 'package:firstvue/services/live_home_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ends_at drives ending soon and ended when present', () {
    final now = DateTime(2026, 8, 15, 12);
    final start = now.subtract(const Duration(hours: 1));
    expect(
      LiveHomeService.lifecycleFor(
        start,
        endsAt: now.add(const Duration(minutes: 30)),
        now: now,
      ),
      LiveLifecycleStatus.endingSoon,
    );
    expect(
      LiveHomeService.lifecycleFor(
        start,
        endsAt: now.add(const Duration(hours: 3)),
        now: now,
      ),
      LiveLifecycleStatus.live,
    );
    expect(
      LiveHomeService.lifecycleFor(
        start,
        endsAt: now.subtract(const Duration(minutes: 1)),
        now: now,
      ),
      LiveLifecycleStatus.ended,
    );
  });

  test('food truck LIVE flag defaults on for Phase 8', () {
    expect(FeatureFlags.liveFoodTrucksEnabled, isTrue);
  });

  test('open session lifecycle uses ends_at only', () {
    final now = DateTime(2026, 8, 15, 12);
    final session = LiveBusinessOpenSession(
      sessionId: 's1',
      businessId: 'b1',
      businessName: 'Taco Truck',
      businessType: 'Food Truck',
      startedAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(minutes: 20)),
    );
    expect(session.isFoodTruck, isTrue);
    expect(session.lifecycle(now: now), LiveLifecycleStatus.endingSoon);
    final item = session.toRightNowItem();
    expect(item.kind, LiveRightNowKind.business);
    expect(item.businessId, 'b1');
  });

  test('phase 7 and 8 migrations are additive and index-safe', () {
    final endsAt =
        File('supabase/migrations/20261006_live_event_ends_at.sql')
            .readAsStringSync();
    expect(endsAt.contains('add column if not exists ends_at'), isTrue);
    expect(endsAt.contains('where ends_at > now()'), isFalse);

    final open = File(
      'supabase/migrations/20261007_live_business_open_sessions.sql',
    ).readAsStringSync();
    expect(open.contains('business_open_sessions'), isTrue);
    expect(open.contains('start_business_open_session'), isTrue);
    expect(open.contains('list_active_business_open_sessions'), isTrue);
    expect(open.contains('[1:100]'), isFalse);
    expect(open.contains('least(coalesce(p_limit, 40), 100)'), isTrue);
    // Indexes must not use now(); RLS may filter with now().
    expect(
      open.contains(
        'on public.business_open_sessions (ends_at desc);\n',
      ),
      isTrue,
    );
  });
}
