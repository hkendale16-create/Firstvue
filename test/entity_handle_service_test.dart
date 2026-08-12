import 'package:firstvue/services/entity_handle_service.dart';
import 'package:firstvue/services/post_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntityHandleService.normalize', () {
    test('reuses username normalization rules', () {
      expect(EntityHandleService.normalize('@Joe_1'), 'joe_1');
      expect(EntityHandleService.normalize('ab'), isNull);
      expect(EntityHandleService.normalize('@@@shop'), 'shop');
    });

    test('autocompletePrefix allows partial handles', () {
      expect(EntityHandleService.autocompletePrefix('@jo'), 'jo');
      expect(EntityHandleService.autocompletePrefix('jo'), isNull);
    });
  });

  group('EntityHandleService.parseSuggestions', () {
    test('maps RPC-shaped rows and skips invalid entries', () {
      final parsed = EntityHandleService.parseSuggestions([
        {
          'handle': 'kendale',
          'display_name': 'Kendale',
          'entity_type': 'user',
          'entity_id': 'u1',
          'priority': 0,
        },
        {
          'handle': 'shop_one',
          'display_name': 'Shop One',
          'entity_type': 'business',
          'entity_id': 'b1',
          'priority': 2,
        },
        {
          'handle': 'bad',
          'entity_type': 'unknown',
          'entity_id': 'x',
        },
        'not-a-map',
      ]);

      expect(parsed, hasLength(2));
      expect(parsed.first.handle, 'kendale');
      expect(parsed.first.priority, 0);
      expect(parsed.first.atHandle, '@kendale');
      expect(parsed.first.entityType, EntityHandleType.user);
      expect(parsed.last.entityType, EntityHandleType.business);
    });
  });

  group('EntityHandleService.mentionTokenAt', () {
    test('extracts active @token before cursor', () {
      expect(EntityHandleService.mentionTokenAt('hi @ken', 7), '@ken');
      expect(EntityHandleService.mentionTokenAt('hi @ken there', 7), '@ken');
      expect(EntityHandleService.mentionTokenAt('hi @ken there', 13), isNull);
      expect(EntityHandleService.mentionTokenAt('no mention', 5), isNull);
    });
  });

  group('PostMetadataService mention parsing', () {
    test('collects @handles from body text', () {
      final parsed = PostMetadataService.parse(
        'Shoutout to @kendale and @shop_one #local',
      );
      expect(parsed.mentionUsernames, containsAll(['kendale', 'shop_one']));
      expect(parsed.hashtags, contains('local'));
    });
  });
}
