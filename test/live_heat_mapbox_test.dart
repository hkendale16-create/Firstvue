import 'dart:io';

import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/config/mapbox_config.dart';
import 'package:firstvue/services/live_heat_service.dart';
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

  test('heat flag and Mapbox config defaults', () {
    expect(FeatureFlags.liveHeatActivityEnabled, isTrue);
    // Token is injected via dart-define / secrets — empty by default in CI.
    expect(MapboxConfig.accessToken, isA<String>());
    expect(MapboxConfig.styleUri.contains('mapbox://styles/'), isTrue);
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

  test('mapbox package is declared', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('mapbox_maps_flutter:'), isTrue);
  });
}
