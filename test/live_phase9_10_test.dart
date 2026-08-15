import 'dart:io';

import 'package:firstvue/services/live_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phase 10 realtime migration adds LIVE tables safely', () {
    final sql = File(
      'supabase/migrations/20261008_live_realtime_publication.sql',
    ).readAsStringSync();
    expect(sql.contains('business_open_sessions'), isTrue);
    expect(sql.contains('event_presence'), isTrue);
    expect(sql.contains('event_hot_reactions'), isTrue);
    expect(sql.contains('supabase_realtime'), isTrue);
    expect(sql.contains('duplicate_object'), isTrue);
  });

  test('LiveRealtimeService exposes home and engagement subscribe APIs', () {
    expect(LiveRealtimeService.subscribeHome, isA<Function>());
    expect(LiveRealtimeService.unsubscribeHome, isA<Function>());
    expect(LiveRealtimeService.subscribeEventEngagement, isA<Function>());
  });
}
