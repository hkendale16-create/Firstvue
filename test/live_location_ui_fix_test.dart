import 'package:firstvue/data/us_locations.dart';
import 'package:firstvue/services/live_map_service.dart';
import 'package:firstvue/widgets/live/live_category_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Live View category icons', () {
    test('every LiveDiscoveryCategory has a distinct Material icon', () {
      final icons = LiveDiscoveryCategory.values.map((c) => c.icon).toSet();
      expect(icons.length, LiveDiscoveryCategory.values.length);
      for (final cat in LiveDiscoveryCategory.values) {
        expect(cat.icon, isNot(Icons.circle));
        expect(cat.icon.fontFamily, isNotNull);
      }
    });

    test('map filters and pin kinds expose icons', () {
      for (final filter in LiveMapFilter.values) {
        expect(filter.icon, isA<IconData>());
      }
      for (final kind in LiveMapPinKind.values) {
        expect(kind.icon, isA<IconData>());
      }
    });
  });

  group('UsLocations state→city', () {
    test('citiesForState returns only that state pool', () {
      final ga = UsLocations.citiesForState('Georgia');
      expect(ga, contains('Atlanta'));
      expect(ga, isNot(contains('Phoenix')));
    });

    test('matchingCities respects stateHint without 3-letter minimum', () {
      final open = UsLocations.matchingCities('', stateHint: 'Arizona');
      expect(open, isNotEmpty);
      expect(open.every(UsLocations.citiesForState('Arizona').contains), isTrue);

      final filtered =
          UsLocations.matchingCities('ph', stateHint: 'Arizona');
      expect(filtered, contains('Phoenix'));
      expect(filtered.every((c) => c.toLowerCase().contains('ph')), isTrue);
    });

    test('matchingCities without state still requires min length', () {
      expect(UsLocations.matchingCities('ph'), isEmpty);
      expect(UsLocations.matchingCities('pho'), isNotEmpty);
    });

    test('every state in UsLocations.states has a city catalog entry', () {
      for (final state in UsLocations.states) {
        expect(
          UsLocations.citiesByState.containsKey(state),
          isTrue,
          reason: 'Missing cities for $state',
        );
        expect(UsLocations.citiesForState(state), isNotEmpty);
      }
    });
  });
}
