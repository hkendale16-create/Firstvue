import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/profile_activity_service.dart';

void main() {
  group('ProfileActivityFilter', () {
    test('all matches every activity type', () {
      for (final type in ProfileActivityType.values) {
        expect(ProfileActivityFilter.all.matches(type), isTrue);
      }
    });

    test('likes matches only spark given/received', () {
      expect(
        ProfileActivityFilter.likes.matches(ProfileActivityType.sparkGiven),
        isTrue,
      );
      expect(
        ProfileActivityFilter.likes.matches(
          ProfileActivityType.sparkReceived,
        ),
        isTrue,
      );
      expect(
        ProfileActivityFilter.likes.matches(ProfileActivityType.newsPost),
        isFalse,
      );
      expect(
        ProfileActivityFilter.likes.matches(ProfileActivityType.savedItem),
        isFalse,
      );
      expect(
        ProfileActivityFilter.likes.matches(ProfileActivityType.sharedPost),
        isFalse,
      );
    });

    test('saves matches only savedItem', () {
      expect(
        ProfileActivityFilter.saves.matches(ProfileActivityType.savedItem),
        isTrue,
      );
      for (final type in ProfileActivityType.values) {
        if (type == ProfileActivityType.savedItem) continue;
        expect(ProfileActivityFilter.saves.matches(type), isFalse);
      }
    });

    test('shares matches only sharedPost', () {
      expect(
        ProfileActivityFilter.shares.matches(ProfileActivityType.sharedPost),
        isTrue,
      );
      for (final type in ProfileActivityType.values) {
        if (type == ProfileActivityType.sharedPost) continue;
        expect(ProfileActivityFilter.shares.matches(type), isFalse);
      }
    });

    test('labels are short and user-facing', () {
      expect(ProfileActivityFilter.all.label, 'All');
      expect(ProfileActivityFilter.likes.label, 'Likes');
      expect(ProfileActivityFilter.saves.label, 'Saves');
      expect(ProfileActivityFilter.shares.label, 'Shares');
    });
  });

  group('ProfileActivityService.extractLink', () {
    test('extracts the first http(s) link from text', () {
      expect(
        ProfileActivityService.extractLink(
          'Check this out: https://firstvue.app/x and more',
        ),
        'https://firstvue.app/x',
      );
    });

    test('returns null when there is no link', () {
      expect(ProfileActivityService.extractLink('no links here'), isNull);
      expect(ProfileActivityService.extractLink(''), isNull);
      expect(ProfileActivityService.extractLink(null), isNull);
    });
  });
}
