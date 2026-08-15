import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LIVE_APPLY_ONCE is index-safe and self-contained', () {
    final sql = File('supabase/LIVE_APPLY_ONCE.sql').readAsStringSync();
    expect(sql.contains('event_presence'), isTrue);
    expect(sql.contains('live_event_heat_scores'), isTrue);
    expect(sql.contains('business_open_sessions'), isTrue);
    expect(sql.contains("'{}'::uuid[]"), isTrue);
    expect(sql.contains('[1:100]'), isFalse);
    // No partial index using now()
    expect(
      RegExp(
        r'create index[\s\S]{0,220}where[\s\S]{0,80}now\(\)',
        multiLine: true,
      ).hasMatch(sql),
      isFalse,
    );
  });

  test('organizer review migration defines atomic RPC', () {
    final sql = File(
      'supabase/migrations/20261009_review_organizer_application.sql',
    ).readAsStringSync();
    expect(sql.contains('review_organizer_application'), isTrue);
    expect(sql.contains('community_organizer_applications'), isTrue);
    expect(sql.contains('is_firstvue_admin'), isTrue);
  });
}
