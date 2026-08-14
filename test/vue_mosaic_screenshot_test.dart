import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/vue_mosaic_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DiscoveryFeedItem fake(int index) {
    return DiscoveryFeedItem(
      mediaId: 'm$index',
      businessId: 'b$index',
      businessName: 'Creator $index',
      businessType: 'Salon',
      ownerId: 'c$index',
      ownerName: 'Creator $index',
      caption: '',
      mediaType: 'image',
      mediaUrl: 'local://$index.jpg',
      verified: index.isEven,
      sponsored: false,
      rating: 0,
      services: const ['Cut'],
      locationLabel: 'Atlanta, GA',
      handle: 'tile$index',
    );
  }

  Future<void> pumpMosaic(
    WidgetTester tester, {
    required Size size,
    required int columns,
    required int itemCount,
  }) async {
    final items = [for (var i = 0; i < itemCount; i++) fake(i)];
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantLight,
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: VueMosaicView(
              items: items,
              columns: columns,
              onOpen: (_) {},
              onOpenProfile: (_) {},
              tileBuilder: (cell, _) {
                return ColoredBox(
                  color: cell.featured
                      ? const Color(0xFFE5C16F)
                      : const Color(0xFF3DD9C9),
                  child: Text(
                    cell.featured ? 'FEATURED 2x2' : '@tile${cell.index}',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mobile mosaic has a 2x2 featured tile beside two 1x1 tiles', (
    tester,
  ) async {
    await pumpMosaic(
      tester,
      size: const Size(390, 720),
      columns: 3,
      itemCount: 12,
    );

    final featured = tester.getSize(find.byKey(const ValueKey('featured-0')));
    final small = tester.getSize(find.byKey(const ValueKey('tile-1')));
    expect(
      featured.width,
      closeTo(small.width * 2 + VueMosaicView.spacing, 12),
    );
    expect(
      featured.height,
      closeTo(small.height * 2 + VueMosaicView.spacing, 12),
    );
  });

  testWidgets('tablet mosaic keeps the quilted 2x2 lead', (tester) async {
    await pumpMosaic(
      tester,
      size: const Size(840, 900),
      columns: 4,
      itemCount: 16,
    );
    final featured = tester.getSize(find.byKey(const ValueKey('featured-0')));
    final small = tester.getSize(find.byKey(const ValueKey('tile-1')));
    expect(featured.width, greaterThan(small.width * 1.5));
    expect(featured.height, greaterThan(small.height * 1.5));
  });

  testWidgets('desktop mosaic keeps the quilted 2x2 lead', (tester) async {
    await pumpMosaic(
      tester,
      size: const Size(1100, 800),
      columns: 5,
      itemCount: 20,
    );
    final featured = tester.getSize(find.byKey(const ValueKey('featured-0')));
    final small = tester.getSize(find.byKey(const ValueKey('tile-1')));
    expect(featured.width, greaterThan(small.width * 1.5));
  });
}
