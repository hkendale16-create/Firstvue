import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/discovery_feed_service.dart';

void main() {
  test('DiscoveryFeedItem media ids are unique keys for pagination', () {
    final a = DiscoveryFeedItem(
      mediaId: 'm1',
      businessId: 'b1',
      businessName: 'A',
      businessType: 'biz',
      ownerId: 'o1',
      ownerName: 'O',
      caption: 'c',
      mediaType: 'image',
      mediaUrl: 'https://example.com/a.jpg',
      verified: false,
      sponsored: false,
      rating: 1,
      services: const [],
    );
    final b = DiscoveryFeedItem(
      mediaId: 'm1',
      businessId: 'b1',
      businessName: 'A-dup',
      businessType: 'biz',
      ownerId: 'o1',
      ownerName: 'O',
      caption: 'c2',
      mediaType: 'image',
      mediaUrl: 'https://example.com/a2.jpg',
      verified: false,
      sponsored: false,
      rating: 1,
      services: const [],
    );
    final c = DiscoveryFeedItem(
      mediaId: 'm2',
      businessId: 'b2',
      businessName: 'B',
      businessType: 'biz',
      ownerId: 'o2',
      ownerName: 'O2',
      caption: 'c3',
      mediaType: 'image',
      mediaUrl: 'https://example.com/b.jpg',
      verified: false,
      sponsored: false,
      rating: 2,
      services: const [],
    );

    final seen = <String>{};
    final deduped = <DiscoveryFeedItem>[];
    for (final item in [a, b, c]) {
      if (!seen.add(item.mediaId)) continue;
      deduped.add(item);
    }

    expect(deduped.map((e) => e.mediaId), ['m1', 'm2']);
    expect(deduped.first.businessName, 'A');
  });
}
