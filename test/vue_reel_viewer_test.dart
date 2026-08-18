import 'package:firstvue/screens/vue_reel_viewer.dart';
import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/firstvue_share_sheet.dart';
import 'package:firstvue/widgets/vue_mosaic_tile.dart';
import 'package:firstvue/widgets/vue_video_player.dart';
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

  test('copyMessage is not counted as a completed share', () {
    expect(vueShareActionCounts(ShareAction.copyMessage), isFalse);
    expect(vueShareActionCounts(ShareAction.copyLink), isTrue);
    expect(vueShareActionCounts(ShareAction.systemShare), isTrue);
    expect(vueShareActionCounts(ShareAction.inAppMessage), isTrue);
    expect(vueShareActionCounts(ShareAction.group), isTrue);
  });

  testWidgets('rail actions do not open the creator profile', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var profileTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: VueReelViewer(
          items: [_item()],
          initialIndex: 0,
          onOpenProfile: (_) => profileTaps++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('vue-reel-like')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('vue-reel-save')));
    await tester.pump();
    expect(profileTaps, 0);

    await tester.tap(find.byKey(const Key('vue-reel-comment')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('COMMENTS'), findsOneWidget);
    expect(profileTaps, 0);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('COMMENTS'), findsNothing);
    expect(find.byType(VueReelViewer), findsOneWidget);
    expect(find.text('VUE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vue-reel-share')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('ROUTE'), findsOneWidget);
    expect(profileTaps, 0);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('@amoursalon'));
    await tester.pump();
    expect(profileTaps, 1);
  });

  testWidgets('long captions expand and collapse with more/less', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: VueReelViewer(
          items: [
            _item(
              caption:
                  'Friday night at the salon is always a show — lights, music, and the whole city showing up in their best.',
            ),
          ],
          initialIndex: 0,
          onOpenProfile: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.text('more'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vue-reel-caption-toggle')));
    await tester.pump();
    expect(find.text('less'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vue-reel-caption-toggle')));
    await tester.pump();
    expect(find.text('more'), findsOneWidget);
  });

  testWidgets('20 photo posts swipe next/previous and jump without leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final items = [
      for (var i = 0; i < 20; i++)
        _item(id: 'media-$i', rank: i + 1, caption: 'Photo $i'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: VueReelViewer(
          items: items,
          initialIndex: 0,
          onOpenProfile: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VueReelViewer), findsOneWidget);
    expect(find.byType(VueVideoPlayer), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(0, -420), 1800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(VueReelViewer), findsOneWidget);
    expect(find.text('VUE'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(0, 420), 1800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(VueReelViewer), findsOneWidget);

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    controller.jumpToPage(1);
    await tester.pump();
    expect(find.text('VUE'), findsOneWidget);
    expect(find.byType(VueReelViewer), findsOneWidget);

    controller.jumpToPage(0);
    await tester.pump();
    expect(find.byType(VueReelViewer), findsOneWidget);

    controller.jumpToPage(19);
    await tester.pump();
    expect(find.byType(VueReelViewer), findsOneWidget);
    expect(find.byType(VueVideoPlayer), findsNothing);
    controller.jumpToPage(0);
    await tester.pump();
    expect(find.byType(VueReelViewer), findsOneWidget);
    expect(find.byType(VueVideoPlayer), findsNothing);
  });
}
