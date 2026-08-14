import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/vue_mosaic_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('photos do not show a video indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantLight,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 200,
            child: VueMosaicTile(
              item: _item(mediaType: 'image', mediaUrl: 'local://still.jpg'),
              featured: false,
              onOpen: () {},
              onOpenProfile: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('vue-video-indicator')), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.movie_filter_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam), findsNothing);
    expect(find.text('@amoursalon'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.text('Atlanta, GA'), findsOneWidget);
    expect(find.text('Salon · Color'), findsOneWidget);
  });

  testWidgets('videos show only a subtle play mark and duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantLight,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 200,
            child: VueMosaicTile(
              item: _item(
                mediaType: 'video',
                mediaUrl: 'local://clip.mp4',
                durationLabel: '0:12',
              ),
              featured: true,
              onOpen: () {},
              onOpenProfile: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('vue-video-indicator')), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    expect(find.byIcon(Icons.movie_filter_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam), findsNothing);
    expect(find.byIcon(Icons.play_circle_filled), findsNothing);
  });
}

DiscoveryFeedItem _item({
  required String mediaType,
  required String mediaUrl,
  String? durationLabel,
}) {
  return DiscoveryFeedItem(
    mediaId: 'media-1',
    businessId: 'biz-1',
    businessName: 'Amour Salon',
    businessType: 'Salon',
    ownerId: 'owner-1',
    ownerName: 'Amour Salon',
    caption: '',
    mediaType: mediaType,
    mediaUrl: mediaUrl,
    durationLabel: durationLabel,
    locationLabel: 'Atlanta, GA',
    handle: 'amoursalon',
    verified: true,
    sponsored: false,
    rating: 5,
    services: const ['Color'],
  );
}
