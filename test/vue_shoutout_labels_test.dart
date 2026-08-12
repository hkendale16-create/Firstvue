import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/services/shoutout_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoveryFeedItem media typing', () {
    test('isVideo uses stored media_type only', () {
      const image = DiscoveryFeedItem(
        mediaId: '1',
        entityId: 'b1',
        entityName: 'Shop',
        entitySubtitle: 'Barber',
        ownerId: 'u1',
        ownerName: 'Owner',
        caption: 'Look',
        mediaType: 'image',
        mediaUrl: 'https://cdn.example/video-looking-name.jpg',
        verified: false,
        sponsored: false,
        rating: 0,
        services: [],
      );
      const video = DiscoveryFeedItem(
        mediaId: '2',
        entityId: 'b1',
        entityName: 'Shop',
        entitySubtitle: 'Barber',
        ownerId: 'u1',
        ownerName: 'Owner',
        caption: 'Clip',
        mediaType: 'video',
        mediaUrl: 'https://cdn.example/still.png',
        verified: false,
        sponsored: false,
        rating: 0,
        services: [],
      );

      expect(image.isVideo, isFalse);
      expect(video.isVideo, isTrue);
    });

    test('viewActionLabel matches entity source', () {
      DiscoveryFeedItem item(VueFeedSource source) => DiscoveryFeedItem(
            mediaId: '1',
            entityId: 'id',
            entityName: 'Name',
            entitySubtitle: 'Type',
            ownerId: 'u',
            ownerName: 'Owner',
            caption: 'c',
            mediaType: 'image',
            mediaUrl: 'https://example.com/x',
            verified: false,
            sponsored: false,
            rating: 0,
            services: const [],
            source: source,
          );

      expect(item(VueFeedSource.business).viewActionLabel, 'View Business');
      expect(item(VueFeedSource.member).viewActionLabel, 'View Profile');
      expect(
        item(VueFeedSource.professional).viewActionLabel,
        'View Professional',
      );
      expect(item(VueFeedSource.event).viewActionLabel, 'View Event');
      expect(item(VueFeedSource.community).viewActionLabel, 'View Community');
    });
  });

  group('ShoutoutTargetType', () {
    test('labels are spelled correctly', () {
      expect(ShoutoutTargetType.business.label, 'Business');
      expect(ShoutoutTargetType.professional.label, 'Professional');
      expect(ShoutoutTargetType.profile.label, 'Person');
      expect(ShoutoutTargetType.event.label, 'Event');
      expect(ShoutoutTargetType.community.label, 'Community');
    });
  });
}
