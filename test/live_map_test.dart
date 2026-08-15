import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/services/live_home_service.dart';
import 'package:firstvue/services/live_map_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';

void main() {
  test('live map flag enabled independently of streaming', () {
    expect(FeatureFlags.liveMapEnabled, isTrue);
    expect(FeatureFlags.liveStreamingEnabled, isFalse);
  });

  test('bounds padding expands viewport for edge pins', () {
    const bounds = LiveMapBounds(
      minLat: 33.7,
      maxLat: 33.8,
      minLng: -84.5,
      maxLng: -84.4,
    );
    final padded = bounds.padded(0.1);
    expect(padded.minLat < bounds.minLat, isTrue);
    expect(padded.maxLat > bounds.maxLat, isTrue);
    expect(padded.contains(const LatLng(33.75, -84.45)), isTrue);
  });

  test('applyFilter keeps tab-specific locations', () {
    final pins = [
      LiveMapPin(
        id: 'a',
        kind: LiveMapPinKind.event,
        title: 'Live Event',
        point: const LatLng(33.75, -84.39),
        lifecycle: LiveLifecycleStatus.live,
      ),
      LiveMapPin(
        id: 'b',
        kind: LiveMapPinKind.event,
        title: 'Later',
        point: const LatLng(33.76, -84.38),
        lifecycle: LiveLifecycleStatus.upcoming,
      ),
      LiveMapPin(
        id: 'c',
        kind: LiveMapPinKind.foodTruck,
        title: 'Tacos',
        point: const LatLng(33.74, -84.40),
        lifecycle: LiveLifecycleStatus.upcoming,
      ),
      LiveMapPin(
        id: 'd',
        kind: LiveMapPinKind.market,
        title: 'Farmers Market',
        point: const LatLng(33.73, -84.41),
        lifecycle: LiveLifecycleStatus.upcoming,
      ),
      LiveMapPin(
        id: 'e',
        kind: LiveMapPinKind.nightlife,
        title: 'Rooftop Bar',
        point: const LatLng(33.72, -84.42),
        lifecycle: LiveLifecycleStatus.upcoming,
      ),
      LiveMapPin(
        id: 'f',
        kind: LiveMapPinKind.foodTruck,
        title: 'Open Truck',
        point: const LatLng(33.71, -84.43),
        lifecycle: LiveLifecycleStatus.live,
      ),
    ];

    expect(LiveMapService.applyFilter(pins, LiveMapFilter.liveNow).length, 2);
    expect(LiveMapService.applyFilter(pins, LiveMapFilter.events).length, 2);
    expect(LiveMapService.applyFilter(pins, LiveMapFilter.foodTrucks).length, 2);
    expect(LiveMapService.applyFilter(pins, LiveMapFilter.markets).length, 1);
    expect(LiveMapService.applyFilter(pins, LiveMapFilter.nightlife).length, 1);
  });

  test('kindForBusinessType maps directory types to tabs', () {
    expect(
      LiveMapService.kindForBusinessType('Food Truck'),
      LiveMapPinKind.foodTruck,
    );
    expect(
      LiveMapService.kindForBusinessType('Sports Bar'),
      LiveMapPinKind.nightlife,
    );
    expect(
      LiveMapService.kindForBusinessType('Farmers Market'),
      LiveMapPinKind.market,
    );
    expect(LiveMapService.kindForBusinessType('Barbershop'), isNull);
    expect(LiveMapService.kindForBusinessType('Restaurant'), isNull);
  });

  test('centroidOf averages pin locations', () {
    final pins = [
      LiveMapPin(
        id: 'a',
        kind: LiveMapPinKind.event,
        title: 'A',
        point: const LatLng(33.0, -84.0),
        lifecycle: LiveLifecycleStatus.live,
      ),
      LiveMapPin(
        id: 'b',
        kind: LiveMapPinKind.event,
        title: 'B',
        point: const LatLng(35.0, -82.0),
        lifecycle: LiveLifecycleStatus.live,
      ),
    ];
    final c = LiveMapService.centroidOf(pins)!;
    expect(c.latitude, closeTo(34.0, 0.001));
    expect(c.longitude, closeTo(-83.0, 0.001));
  });

  test('visibleFilters respects food truck flag', () {
    expect(
      LiveMapService.visibleFilters().contains(LiveMapFilter.foodTrucks),
      FeatureFlags.liveFoodTrucksEnabled,
    );
  });

  test('geo migration is additive and nullable', () {
    final sql =
        File('supabase/migrations/20261002_live_event_geo.sql').readAsStringSync();
    expect(sql.contains('add column if not exists latitude'), isTrue);
    expect(sql.contains('add column if not exists longitude'), isTrue);
    expect(sql.contains('community_events_geo_idx'), isTrue);
  });

  test('pubspec includes flutter_map for interactive LIVE map', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter_map:'), isTrue);
    expect(pubspec.contains('latlong2:'), isTrue);
  });
}
