import 'dart:io';

import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/services/trending_businesses_service.dart';
import 'package:firstvue/services/user_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ranked feed catalog fallback', () {
    test('empty or non-list RPC is a catalog miss for guests and members', () {
      expect(CommunityNewsService.rankedRpcMissedCatalog(null), isTrue);
      expect(CommunityNewsService.rankedRpcMissedCatalog(<dynamic>[]), isTrue);
      expect(
        CommunityNewsService.rankedRpcMissedCatalog(<String, dynamic>{}),
        isTrue,
      );
      expect(
        CommunityNewsService.rankedRpcMissedCatalog([
          {'id': 'p1'},
        ]),
        isFalse,
      );
    });

    test('signed-in empty RPC no longer returns an empty list', () {
      final src = File(
        'lib/services/community_news_service.dart',
      ).readAsStringSync();
      expect(
        src.contains('me == null ? await fetchPosts(limit: limit) : const []'),
        isFalse,
      );
      expect(src.contains('rankedRpcMissedCatalog'), isTrue);
      expect(src.contains('_publicHomeCatalog'), isTrue);
    });
  });

  group('discovery prefs', () {
    test('saved city-chip prefs win', () {
      const saved = UserPreferences(
        locationCity: 'Atlanta',
        locationState: 'GA',
      );
      const local = UserPreferences(browseEverywhere: true);
      final prefs = UserPreferencesService.discoveryPreferences(
        savedRow: saved,
        local: local,
      );
      expect(prefs.locationCity, 'Atlanta');
      expect(prefs.browseEverywhere, isFalse);
    });

    test('without a saved row, local guest prefs are used', () {
      const local = UserPreferences();
      final prefs = UserPreferencesService.discoveryPreferences(
        savedRow: null,
        local: local,
      );
      expect(prefs.locationCity, isNull);
      expect(prefs.locationState, isNull);
    });

    test('profile address is not used as a discovery lock', () {
      final src = File(
        'lib/services/user_preferences_service.dart',
      ).readAsStringSync();
      expect(src.contains('UserProfileService.fetchProfile'), isFalse);
      expect(src.contains('profile?.city'), isFalse);
    });
  });

  group('trending location filter', () {
    test('empty location matches keep the public catalog', () {
      const prefs = UserPreferences(
        locationCity: 'Atlanta',
        locationState: 'GA',
      );
      final rows = [
        {
          'id': 'b1',
          'business_locations': [
            {'city': 'Austin', 'state': 'TX'},
          ],
        },
        {
          'id': 'b2',
          'business_locations': [
            {'city': 'Miami', 'state': 'FL'},
          ],
        },
      ];
      final filtered = TrendingBusinessesService.filterByPreferredLocationOrAll(
        rows,
        prefs,
      );
      expect(filtered, hasLength(2));
    });

    test('matching local businesses are kept when present', () {
      const prefs = UserPreferences(
        locationCity: 'Atlanta',
        locationState: 'GA',
      );
      final rows = [
        {
          'id': 'b1',
          'business_locations': [
            {'city': 'Atlanta', 'state': 'GA'},
          ],
        },
        {
          'id': 'b2',
          'business_locations': [
            {'city': 'Miami', 'state': 'FL'},
          ],
        },
      ];
      final filtered = TrendingBusinessesService.filterByPreferredLocationOrAll(
        rows,
        prefs,
      );
      expect(filtered, hasLength(1));
      expect(filtered.first['id'], 'b1');
    });

    test('browseEverywhere keeps every row', () {
      const prefs = UserPreferences(
        locationCity: 'Atlanta',
        browseEverywhere: true,
      );
      final rows = [
        {
          'id': 'b1',
          'business_locations': [
            {'city': 'Miami', 'state': 'FL'},
          ],
        },
      ];
      expect(
        TrendingBusinessesService.filterByPreferredLocationOrAll(rows, prefs),
        hasLength(1),
      );
    });
  });
}
