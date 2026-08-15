import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/widgets/vue_mosaic_tile.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('VUE mosaic does not pass .mov URLs to Image.network', (
    tester,
  ) async {
    final item = DiscoveryFeedItem(
      mediaId: 'vid-1',
      businessId: '',
      businessName: 'Clip',
      businessType: 'VUE',
      ownerId: 'owner-1',
      ownerName: 'Owner',
      caption: 'video only',
      mediaType: 'video',
      mediaUrl:
          'https://sdssshegqdwobjelxzkp.supabase.co/storage/v1/object/sign/community-news-media/x.mov?token=abc',
      thumbnailUrl: null,
      verified: false,
      sponsored: false,
      rating: 0,
      services: const [],
      source: VueFeedSource.member,
      newsPostId: 'post-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 200,
            child: VueMosaicTile(
              item: item,
              featured: false,
              onOpen: () {},
              onOpenProfile: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });
}
