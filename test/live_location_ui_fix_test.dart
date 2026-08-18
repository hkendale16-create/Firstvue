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
      expect(ga, contains('Marietta'));
      expect(ga, contains('Decatur'));
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

    test('matchingCities does not cap an in-state catalog', () {
      final all = UsLocations.citiesForState('California');
      final opened = UsLocations.matchingCities('', stateHint: 'California');
      expect(opened, hasLength(all.length));
      expect(opened.length, greaterThan(60));
    });

    test('matchingCities includes a typed city that is not in the catalog', () {
      final results = UsLocations.matchingCities(
        'powder springs',
        stateHint: 'Georgia',
      );
      expect(results, contains('Powder Springs'));

      final custom = UsLocations.matchingCities(
        'tybee island',
        stateHint: 'Georgia',
      );
      expect(custom, contains('Tybee Island'));
    });

    test('titleCaseCity formats custom entries', () {
      expect(UsLocations.titleCaseCity('east point'), 'East Point');
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
