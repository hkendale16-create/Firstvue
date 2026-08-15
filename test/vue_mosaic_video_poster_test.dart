import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/widgets/explore_grid_video.dart';
import 'package:firstvue/widgets/vue_mosaic_tile.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('VUE mosaic videos use ExploreGridVideo for 3s loops', (
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
    // VisibilityDetector schedules a short update timer.
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ExploreGridVideo), findsOneWidget);
    expect(ExploreGridVideo.previewLoop, const Duration(seconds: 3));
    // Must not decode the .mov as an Image.network source.
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('non-http video URLs keep the static play fallback', (
    tester,
  ) async {
    final item = DiscoveryFeedItem(
      mediaId: 'vid-2',
      businessId: '',
      businessName: 'Clip',
      businessType: 'VUE',
      ownerId: 'owner-1',
      ownerName: 'Owner',
      caption: 'local',
      mediaType: 'video',
      mediaUrl: 'local://clip.mp4',
      thumbnailUrl: null,
      verified: false,
      sponsored: false,
      rating: 0,
      services: const [],
      source: VueFeedSource.member,
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

    expect(find.byType(ExploreGridVideo), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
  });
}
