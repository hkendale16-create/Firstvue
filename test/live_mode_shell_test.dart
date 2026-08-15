import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/screens/live_home_shell_screen.dart';
import 'package:firstvue/services/live_home_service.dart';
import 'package:firstvue/services/live_mode_preference.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/live/live_right_now_card.dart';
import 'package:firstvue/widgets/vue_live_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

LiveHomeSnapshot _emptySnap({String title = '🔥 HAPPENING NOW'}) {
  return LiveHomeSnapshot(
    rightNowTitle: title,
    cityName: null,
    rightNow: const [],
    vueItems: const [],
  );
}

LiveHomeSnapshot _eventSnap() {
  final item = LiveRightNowItem(
    id: 'evt-1',
    kind: LiveRightNowKind.event,
    title: 'Afrobeats Rooftop',
    subtitle: 'Midtown',
    lifecycle: LiveLifecycleStatus.live,
    goingCount: 3,
    locationLabel: 'Midtown',
  );
  return LiveHomeSnapshot(
    rightNowTitle: '🔥 ATLANTA RIGHT NOW',
    cityName: 'Atlanta',
    rightNow: [item],
    vueItems: const [],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LiveModePreference.debugReset();
  });

  test('rightNowHeading uses city and falls back without hardcoding Atlanta', () {
    expect(
      LiveHomeService.rightNowHeading('Charlotte'),
      '🔥 CHARLOTTE RIGHT NOW',
    );
    expect(LiveHomeService.rightNowHeading(null), '🔥 HAPPENING NOW');
    expect(LiveHomeService.rightNowHeading('Everywhere'), '🔥 HAPPENING NOW');
  });

  test('lifecycleFor derives LIVE / STARTING SOON from event_at', () {
    final now = DateTime(2026, 8, 15, 12);
    expect(
      LiveHomeService.lifecycleFor(now.subtract(const Duration(hours: 1)), now: now),
      LiveLifecycleStatus.live,
    );
    expect(
      LiveHomeService.lifecycleFor(now.add(const Duration(minutes: 30)), now: now),
      LiveLifecycleStatus.startingSoon,
    );
    expect(
      LiveHomeService.lifecycleFor(now.add(const Duration(hours: 5)), now: now),
      LiveLifecycleStatus.upcoming,
    );
    expect(
      LiveHomeService.lifecycleFor(now.subtract(const Duration(hours: 8)), now: now),
      LiveLifecycleStatus.ended,
    );
  });

  test('live_mode flag is distinct from livestream streaming flag', () {
    expect(FeatureFlags.liveModeEnabled, isTrue);
    expect(FeatureFlags.liveStreamingEnabled, isFalse);
    expect(FeatureFlags.liveMapEnabled, isTrue);
  });

  testWidgets('LIVE home empty state and map CTA render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: LiveHomeShellScreen(
            initialSnapshot: _emptySnap(),
            onReturnToVue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔥 HAPPENING NOW'), findsOneWidget);
    expect(find.textContaining('quiet here right now'), findsOneWidget);
    expect(find.textContaining('Explore Live Map'), findsOneWidget);
    expect(find.text('VUE FEED'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
  });

  testWidgets('LIVE home shows real Right Now cards without inventing counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: LiveHomeShellScreen(initialSnapshot: _eventSnap()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🔥 ATLANTA RIGHT NOW'), findsOneWidget);
    expect(find.byType(LiveRightNowCard), findsOneWidget);
    expect(find.text('Afrobeats Rooftop'), findsOneWidget);
    expect(find.textContaining('3 going'), findsOneWidget);
  });

  testWidgets('Food category shows honest backend gap, not fake truck counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: LiveHomeShellScreen(initialSnapshot: _eventSnap()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No LIVE food yet'), findsOneWidget);
    expect(find.textContaining('will not invent'), findsOneWidget);
    expect(find.text('4 LIVE TRUCKS'), findsNothing);
  });

  testWidgets('mode switch harness still restores VUE', (tester) async {
    FirstVueExperienceMode mode = FirstVueExperienceMode.live;
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: Column(
            children: [
              VueLiveModeSwitch(
                mode: mode,
                onChanged: (next) => mode = next,
              ),
              const Expanded(child: Text('LIVE_BODY')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('VUE'));
    await tester.pump();
    expect(mode, FirstVueExperienceMode.vue);
  });
}
