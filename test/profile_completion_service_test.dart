import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/profile_completion_service.dart';

void main() {
  group('ProfileCompletionService', () {
    test('user scoring uses existing fields only', () {
      final empty = ProfileCompletionService.score(
        type: ProfileEntityType.user,
        fields: {
          'display_name': '',
          'username': '',
          'bio': '',
          'city': '',
          'website': '',
        },
      );
      expect(empty.filledCount, 0);
      expect(empty.totalCount, 5);
      expect(empty.percent, 0);
      expect(empty.nextMissing, 'Display name');

      final partial = ProfileCompletionService.score(
        type: ProfileEntityType.user,
        fields: {
          'display_name': 'Kendale',
          'username': 'kendale',
          'bio': 'Hello',
          'city': '',
          'website': '',
          'phone': '',
          'has_avatar': false,
        },
      );
      expect(partial.filledCount, 3);
      expect(partial.totalCount, 7);
      expect(partial.missingLabels.first, 'City');
      expect(partial.ratio, closeTo(3 / 7, 0.001));
    });

    test('business scoring ignores unknown fake fields', () {
      final result = ProfileCompletionService.score(
        type: ProfileEntityType.business,
        fields: {
          'name': 'FirstVue Studio',
          'description': 'Barber shop',
          'services': ['Fade', 'Beard'],
          'city': 'Atlanta',
          'state': 'GA',
          'made_up_field': 'nope',
        },
      );
      expect(result.isComplete, isTrue);
      expect(result.percent, 100);
      expect(result.missingLabels, isEmpty);
    });

    test('professional rental group community scoring', () {
      final pro = ProfileCompletionService.score(
        type: ProfileEntityType.professional,
        fields: {
          'display_name': 'Alex',
          'bio': '',
          'city': 'Austin',
          'state': 'TX',
          'services': <String>[],
          'booking_url': 'https://book.me',
        },
      );
      expect(pro.missingLabels, containsAll(['Bio', 'Services']));
      expect(pro.filledCount, 4);

      final rental = ProfileCompletionService.score(
        type: ProfileEntityType.rental,
        fields: {
          'title': 'Downtown loft',
          'description': 'Nice place',
          'city': 'Dallas',
          'monthly_price_cents': 120000,
          'has_media': true,
        },
      );
      expect(rental.missingLabels, isEmpty);
      expect(rental.percent, 100);

      final group = ProfileCompletionService.score(
        type: ProfileEntityType.group,
        fields: {
          'name': 'Creators',
          'description': 'Local creators',
          'category': 'Arts',
          'city': '',
        },
      );
      expect(group.nextMissing, 'City');
      expect(group.percent, 75);

      final community = ProfileCompletionService.score(
        type: ProfileEntityType.community,
        fields: {
          'name': 'Atlanta Hub',
          'description': 'City hub',
          'category': 'Local',
          'city': 'Atlanta',
          'rules': 'Be kind',
        },
      );
      expect(community.isComplete, isTrue);
    });
  });
}
