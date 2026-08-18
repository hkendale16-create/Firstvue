import 'package:firstvue/screens/vue_reel_viewer.dart';
import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/vue_mosaic_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DiscoveryFeedItem _item({
  String id = 'media-1',
  String mediaType = 'image',
  int rank = 7,
  String caption = 'How am I #Atlanta #NightLife',
}) {
  return DiscoveryFeedItem(
    mediaId: id,
    businessId: 'biz-1',
    businessName: 'Amour Salon',
    businessType: 'Salon',
    ownerId: 'owner-1',
    ownerName: 'Amour Salon',
    caption: caption,
    mediaType: mediaType,
    mediaUrl: 'local://$id.jpg',
    thumbnailUrl: 'local://$id.jpg',
    handle: 'amoursalon',
    verified: true,
    sponsored: false,
    rating: 5,
    services: const [],
    likesCount: 1842,
    commentsCount: 246,
    sharesCount: 84,
    viewsCount: 12400,
    playsCount: 14100,
    trendingRank: rank,
  );
}

void main() {
  testWidgets('mosaic tiles show a compact trending badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantLight,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 200,
            child: VueMosaicTile(
              item: _item(),
              featured: false,
              onOpen: () {},
              onOpenProfile: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('vue-trending-badge-7')), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);
  });

  testWidgets('tapping mosaic media opens the reel, not the profile', (
    tester,
  ) async {
    var openedMedia = false;
    var openedProfile = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantLight,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 200,
            child: VueMosaicTile(
              item: _item(),
              featured: false,
              onOpen: () => openedMedia = true,
              onOpenProfile: () => openedProfile = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(VueMosaicTile));
    expect(openedMedia, isTrue);
    expect(openedProfile, isFalse);
  });

  testWidgets('reel viewer shows overlay counts without leaving the post', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: VueReelViewer(
          items: [
            _item(id: 'one', rank: 1),
            _item(id: 'two', rank: 2),
          ],
          initialIndex: 0,
          onOpenProfile: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('VUE'), findsOneWidget);
    expect(find.byKey(const Key('vue-reel-like')), findsOneWidget);
    expect(find.byKey(const Key('vue-reel-comment')), findsOneWidget);
    expect(find.byKey(const Key('vue-reel-share')), findsOneWidget);
    expect(find.byKey(const Key('vue-reel-save')), findsOneWidget);
    expect(find.textContaining('#1 Trending'), findsWidgets);
    expect(find.text('@amoursalon'), findsOneWidget);
    expect(find.text('1.8K'), findsOneWidget);
    expect(find.text('246'), findsOneWidget);
    expect(find.textContaining('12K views'), findsOneWidget);
  });
}
