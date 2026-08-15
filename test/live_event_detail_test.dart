import 'dart:io';

import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/screens/live_event_detail_screen.dart';
import 'package:firstvue/services/live_event_engagement_service.dart';
import 'package:firstvue/services/things_to_do_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presence expires after expires_at', () {
    final now = DateTime.utc(2026, 8, 15, 21);
    expect(
      LiveEventEngagementService.isPresenceActive(
        now.add(const Duration(hours: 1)),
        now: now,
      ),
      isTrue,
    );
    expect(
      LiveEventEngagementService.isPresenceActive(
        now.subtract(const Duration(minutes: 1)),
        now: now,
      ),
      isFalse,
    );
  });

  test('Phase 3 flags enable presence and chat independently of map', () {
    expect(FeatureFlags.liveEventPresenceEnabled, isTrue);
    expect(FeatureFlags.liveEventChatEnabled, isTrue);
    expect(FeatureFlags.liveMapEnabled, isFalse);
  });

  test('migration defines presence expiry + ownership RLS/RPC', () {
    final sql = File(
      'supabase/migrations/20261001_live_event_presence_hot.sql',
    ).readAsStringSync();
    expect(sql.contains('create table if not exists public.event_presence'), isTrue);
    expect(sql.contains('create table if not exists public.event_hot_reactions'), isTrue);
    expect(sql.contains('expires_at'), isTrue);
    expect(sql.contains('profile_id = auth.uid()'), isTrue);
    expect(sql.contains('set_event_presence'), isTrue);
    expect(sql.contains('clear_event_presence'), isTrue);
    expect(sql.contains('event_here_now_count'), isTrue);
    expect(sql.contains('latitude'), isFalse);
    expect(sql.contains('longitude'), isFalse);
  });

  testWidgets('LIVE event detail shows reactions and utilities', (tester) async {
    final event = CommunityEvent(
      id: 'proto-detail-1',
      title: 'Afrobeats Rooftop',
      description: 'Night rooftop set',
      eventAt: DateTime.now().subtract(const Duration(minutes: 30)),
      locationLabel: 'Midtown Atlanta',
      businessName: 'Skyline Rooftop',
      status: 'approved',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: LiveEventDetailScreen(event: event),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Afrobeats Rooftop'), findsOneWidget);
    expect(find.textContaining('LIVE'), findsWidgets);
    expect(find.text('🔥 Hot'), findsOneWidget);
    expect(find.text('🙌 Going'), findsOneWidget);
    expect(find.textContaining('I’m Here'), findsOneWidget);
    expect(find.textContaining('Open Chat'), findsOneWidget);
    expect(find.textContaining('Directions'), findsOneWidget);
    expect(find.text('LIVE VUES FROM HERE'), findsOneWidget);
    expect(find.text('EVENT INFO'), findsOneWidget);
  });
}
