import 'dart:io';

import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/config/mapbox_config.dart';
import 'package:firstvue/services/live_heat_service.dart';
import 'package:firstvue/services/live_home_service.dart';
import 'package:firstvue/services/live_map_service.dart';
import 'package:firstvue/services/things_to_do_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('heat thresholds require enough recent activity', () {
    expect(
      LiveHeatService.statusForScore(
        score: 2,
        signalCount: 1,
        hereNow: 0,
        vueRecent: 0,
      ),
      isNull,
    );
    expect(
      LiveHeatService.statusForScore(
        score: 5,
        signalCount: 2,
        hereNow: 0,
        vueRecent: 0,
      ),
      LiveHeatStatus.active,
    );
    expect(
      LiveHeatService.statusForScore(
        score: 10,
        signalCount: 4,
        hereNow: 1,
        vueRecent: 1,
      ),
      LiveHeatStatus.heatingUp,
    );
    expect(
      LiveHeatService.statusForScore(
        score: 25,
        signalCount: 6,
        hereNow: 2,
        vueRecent: 1,
      ),
      LiveHeatStatus.hot,
    );
  });

  test('Mapbox native gate requires token and mobile OS', () {
    expect(MapboxConfig.accessToken, isA<String>());
    expect(MapboxConfig.styleUri.contains('mapbox://styles/'), isTrue);
    // CI / Linux agents always fall back — canUseNativeMap must match surface.
    expect(MapboxConfig.canUseNativeMap, isFalse);
    expect(MapboxConfig.fallbackBanner.isNotEmpty, isTrue);
    expect(FeatureFlags.liveHeatActivityEnabled, isTrue);
  });

  test('heat migration RPC exists and is thresholded', () {
    final sql = File(
      'supabase/migrations/20261003_live_heat_activity.sql',
    ).readAsStringSync();
    expect(sql.contains('live_event_heat_scores'), isTrue);
    expect(sql.contains('heating_up'), isTrue);
    expect(sql.contains('here_now'), isTrue);
    expect(sql.contains('security definer'), isTrue);
  });

  test('phase 6 hardening migration locks presence writes and caps heat', () {
    final sql = File(
      'supabase/migrations/20261004_live_phase6_hardening.sql',
    ).readAsStringSync();
    expect(sql.contains('Users insert own event presence'), isTrue);
    expect(sql.contains('drop policy'), isTrue);
    expect(sql.contains('event_hot_count'), isTrue);
    expect(sql.contains('limit 100'), isTrue);
    expect(sql.contains('Users read own event presence'), isTrue);
  });

  test('mapbox package is declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('mapbox_maps_flutter:'), isTrue);
  });

  test('visibleFilters hides food trucks when flag is off', () {
    // Phase 8 defaults the flag on; still expose the helper.
    expect(
      LiveMapService.visibleFilters().contains(LiveMapFilter.foodTrucks),
      FeatureFlags.liveFoodTrucksEnabled,
    );
  });

  test('lifecycleFor keeps same-day legacy events without ends_at', () {
    final now = DateTime(2026, 8, 15, 12);
    expect(
      LiveHomeService.lifecycleFor(
        now.subtract(const Duration(hours: 5, minutes: 30)),
        now: now,
      ),
      LiveLifecycleStatus.live,
    );
    expect(
      LiveHomeService.lifecycleFor(
        now.subtract(const Duration(hours: 2)),
        now: now,
      ),
      LiveLifecycleStatus.live,
    );
    expect(
      LiveHomeService.lifecycleFor(
        DateTime(2026, 8, 15, 23, 30),
        now: DateTime(2026, 8, 15, 23, 20),
      ),
      LiveLifecycleStatus.startingSoon,
    );
    expect(
      LiveHomeService.lifecycleFor(
        DateTime(2026, 8, 15, 10),
        now: DateTime(2026, 8, 15, 23, 30),
      ),
      LiveLifecycleStatus.endingSoon,
    );
  });

  test('directions prefer coordinates when present on CommunityEvent', () {
    const withCoords = CommunityEvent(
      id: 'e1',
      title: 'Rooftop',
      description: null,
      eventAt: null,
      locationLabel: 'Midtown',
      businessName: null,
      latitude: 33.75,
      longitude: -84.39,
    );
    expect(withCoords.hasCoordinates, isTrue);
    const without = CommunityEvent(
      id: 'e2',
      title: 'Rooftop',
      description: null,
      eventAt: null,
      locationLabel: 'Midtown',
      businessName: null,
    );
    expect(without.hasCoordinates, isFalse);
  });
}
