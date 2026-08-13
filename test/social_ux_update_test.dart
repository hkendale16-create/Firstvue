import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/saved_items_service.dart';
import 'package:firstvue/services/story_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublishDestination', () {
    test('parses known values and defaults to feed', () {
      expect(PublishDestination.parse('vue'), PublishDestination.vue);
      expect(
        PublishDestination.parse('feed_and_vue'),
        PublishDestination.feedAndVue,
      );
      expect(PublishDestination.parse(null), PublishDestination.feed);
      expect(PublishDestination.parse('nope'), PublishDestination.feed);
    });

    test('home vs VUE visibility', () {
      expect(PublishDestination.feed.appearsOnHome, isTrue);
      expect(PublishDestination.feed.appearsOnVue, isFalse);
      expect(PublishDestination.vue.appearsOnHome, isFalse);
      expect(PublishDestination.vue.appearsOnVue, isTrue);
      expect(PublishDestination.feedAndVue.appearsOnHome, isTrue);
      expect(PublishDestination.feedAndVue.appearsOnVue, isTrue);
    });
  });

  group('SavedContentType', () {
    test('parses extended types', () {
      expect(SavedContentType.parse('news_post'), SavedContentType.newsPost);
      expect(SavedContentType.parse('business'), SavedContentType.business);
      expect(SavedContentType.parse('vue_media'), SavedContentType.vueMedia);
      expect(SavedContentType.parse('story'), SavedContentType.story);
    });
  });

  group('Story expiry', () {
    test('isExpired is based on expiresAt', () {
      final live = StoryItem(
        id: 's1',
        ownerId: 'u1',
        ownerName: 'Kendale',
        entityType: 'user',
        entityId: 'u1',
        mediaPath: 'u1/stories/a.jpg',
        mediaUrl: 'https://example.com/a.jpg',
        mediaKind: 'image',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );
      final expired = StoryItem(
        id: 's2',
        ownerId: 'u1',
        ownerName: 'Kendale',
        entityType: 'user',
        entityId: 'u1',
        mediaPath: 'u1/stories/b.jpg',
        mediaUrl: 'https://example.com/b.jpg',
        mediaKind: 'image',
        createdAt: DateTime.now().subtract(const Duration(hours: 30)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 6)),
      );
      expect(live.isExpired, isFalse);
      expect(expired.isExpired, isTrue);
    });

    test('unseen rings prefer stories not viewed by me', () {
      final ring = StoryRing(
        ownerId: 'u2',
        ownerName: 'Alex',
        entityType: 'user',
        entityId: 'u2',
        stories: [
          StoryItem(
            id: 's1',
            ownerId: 'u2',
            ownerName: 'Alex',
            entityType: 'user',
            entityId: 'u2',
            mediaPath: 'p',
            mediaUrl: 'u',
            mediaKind: 'image',
            createdAt: DateTime.now(),
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            viewedByMe: false,
          ),
        ],
      );
      expect(ring.hasUnseen, isTrue);
    });
  });
}
