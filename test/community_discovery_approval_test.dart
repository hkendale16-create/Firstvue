import 'package:firstvue/services/community_hub_service.dart';
import 'package:firstvue/services/user_preferences_service.dart';
import 'package:firstvue/utils/location_match.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocationMatch', () {
    test('normalize trims and lowercases', () {
      expect(LocationMatch.normalize('  Atlanta! '), 'atlanta');
    });

    test('browseEverywhere matches everything', () {
      const prefs = UserPreferences(browseEverywhere: true);
      expect(
        LocationMatch.matchesRow(
          prefs: prefs,
          city: null,
          state: null,
          metroArea: null,
        ),
        isTrue,
      );
    });

    test('city or metro match succeeds', () {
      const prefs = UserPreferences(
        locationCity: 'Atlanta',
        locationState: 'GA',
      );
      expect(
        LocationMatch.matchesRow(
          prefs: prefs,
          city: 'Atlanta',
          state: 'GA',
          metroArea: 'Atlanta Metro',
        ),
        isTrue,
      );
      expect(
        LocationMatch.matchesRow(
          prefs: prefs,
          city: null,
          state: null,
          metroArea: 'Atlanta',
        ),
        isTrue,
      );
    });

    test('incomplete optional location does not match set prefs', () {
      const prefs = UserPreferences(
        locationCity: 'Atlanta',
        locationState: 'GA',
      );
      expect(
        LocationMatch.matchesRow(
          prefs: prefs,
          city: null,
          state: null,
          metroArea: null,
        ),
        isFalse,
      );
    });

    test('postgrest filter null when browsing everywhere', () {
      const prefs = UserPreferences(browseEverywhere: true);
      expect(LocationMatch.postgrestOrFilter(prefs), isNull);
    });

    test('postgrest filter includes metro_area', () {
      const prefs = UserPreferences(
        locationCity: 'Atlanta',
        locationState: 'GA',
      );
      final filter = LocationMatch.postgrestOrFilter(prefs)!;
      expect(filter.contains('metro_area.ilike.%Atlanta%'), isTrue);
      expect(filter.contains('city.ilike.%Atlanta%'), isTrue);
      expect(filter.contains('state.ilike.%GA%'), isTrue);
    });
  });

  group('CommunityHub leadership fields', () {
    test('fromRow does not invent leader from created_by', () {
      final hub = CommunityHub.fromRow({
        'id': 'h1',
        'name': 'Atlanta Community',
        'created_by_profile_id': 'creator-1',
        'leader_user_id': null,
        'status': 'active',
        'visibility': 'public',
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      expect(hub.leaderUserId, isNull);
      expect(hub.createdByProfileId, 'creator-1');
      expect(hub.isDiscoverable, isTrue);
    });

    test('pending-status hubs are not discoverable', () {
      final hub = CommunityHub.fromRow({
        'id': 'h2',
        'name': 'Pending Hub',
        'created_by_profile_id': 'u1',
        'status': 'pending',
        'visibility': 'public',
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      expect(hub.isDiscoverable, isFalse);
    });
  });
}
