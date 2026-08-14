import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/widgets/vue_mosaic_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'leading featured spans 2 columns and 2 rows with stacked 1x1 beside',
    () {
      final cells = buildVueMosaic(itemCount: 12, columns: 3);
      expect(cells, isNotEmpty);
      expect(cells.first.featured, isTrue);
      expect(cells.first.columnSpan, 2);
      expect(cells.first.rowSpan, 2);
      expect(cells.first.column, 0);
      expect(cells.first.row, 0);

      final beside = cells
          .where((cell) => !cell.featured && cell.column == 2)
          .toList();
      expect(beside.take(2).map((cell) => cell.row).toList(), [0, 1]);
      expect(
        beside
            .take(2)
            .every((cell) => cell.columnSpan == 1 && cell.rowSpan == 1),
        isTrue,
      );
    },
  );

  test(
    'mosaic continues with a full three-column row then a flipped featured',
    () {
      final cells = buildVueMosaic(itemCount: 12, columns: 3);
      final rowTwo = cells.where((cell) => cell.row == 2).toList()
        ..sort((a, b) => a.column.compareTo(b.column));
      expect(rowTwo.map((cell) => cell.column), [0, 1, 2]);
      expect(
        rowTwo.every((cell) => !cell.featured && cell.columnSpan == 1),
        isTrue,
      );

      final secondFeatured = cells.where((cell) => cell.featured).skip(1).first;
      expect(secondFeatured.column, 1);
      expect(secondFeatured.columnSpan, 2);
      expect(secondFeatured.rowSpan, 2);
    },
  );

  test('cells never overlap and never use source-media dimensions', () {
    for (final columns in [3, 4, 5]) {
      final cells = buildVueMosaic(itemCount: 40, columns: columns);
      final seen = <String>{};
      for (final cell in cells) {
        expect(cell.columnSpan == 2 && cell.rowSpan == 2, cell.featured);
        if (!cell.featured) {
          expect(cell.columnSpan, 1);
          expect(cell.rowSpan, 1);
        }
        for (var y = 0; y < cell.rowSpan; y++) {
          for (var x = 0; x < cell.columnSpan; x++) {
            final key = '${cell.row + y}:${cell.column + x}';
            expect(
              seen.contains(key),
              isFalse,
              reason: 'overlap at $key cols=$columns',
            );
            seen.add(key);
          }
        }
      }
      expect(cells.length, 40);
    }
  });

  test(
    'narrow layouts stay 1x1 and trailing spinner never becomes featured',
    () {
      final narrow = buildVueMosaic(itemCount: 6, columns: 2);
      expect(
        narrow.every((cell) => !cell.featured && cell.columnSpan == 1),
        isTrue,
      );

      final withSpinner = buildVueMosaicWithTrailing(
        itemCount: 6,
        columns: 3,
        trailingCount: 1,
      );
      expect(withSpinner.last.featured, isFalse);
      expect(withSpinner.last.columnSpan, 1);
      expect(withSpinner.last.index, 6);
    },
  );

  test('featured assignment skips the last featured creator', () {
    final ranked = [
      _item('a', 'creator-a'),
      _item('b', 'creator-a'),
      _item('c', 'creator-b'),
      _item('d', 'creator-c'),
    ];
    final cells = buildVueMosaic(itemCount: ranked.length, columns: 3);
    final arranged = assignVueMosaicItems(
      ranked: ranked,
      cells: cells,
      creatorId: (item) => item.creatorId,
      lastFeaturedCreatorId: 'creator-a',
    );
    expect(arranged.first.creatorId, 'creator-b');
    expect(arranged.map((item) => item.mediaId).toSet(), {'a', 'b', 'c', 'd'});
    expect(
      leadingFeaturedCreatorId(
        items: arranged,
        cells: cells,
        creatorId: (item) => item.creatorId,
      ),
      'creator-b',
    );
  });

  test('featured band groups two stacked 1x1 tiles beside the 2x2', () {
    final bands = groupVueMosaicBands(
      buildVueMosaic(itemCount: 12, columns: 3),
    );
    expect(bands.first, isA<VueFeaturedBand>());
    final lead = bands.first as VueFeaturedBand;
    expect(lead.featured.columnSpan, 2);
    expect(lead.stacked, hasLength(2));
    expect(bands[1], isA<VueUniformBand>());
    expect((bands[1] as VueUniformBand).tiles, hasLength(3));
    expect(bands[2], isA<VueFeaturedBand>());
    expect((bands[2] as VueFeaturedBand).featured.column, 1);
  });

  test('duration and location formatters keep overlays compact', () {
    expect(formatVueDuration(12), '0:12');
    expect(formatVueDuration(75), '1:15');
    expect(formatVueDuration(null), isNull);
    expect(vueLocationLabel(city: 'Atlanta', state: 'GA'), 'Atlanta, GA');
    expect(vueLocationLabel(city: '  ', state: null), isNull);
  });
}

DiscoveryFeedItem _item(String id, String owner) {
  return DiscoveryFeedItem(
    mediaId: id,
    businessId: owner,
    businessName: owner,
    businessType: 'Salon',
    ownerId: owner,
    ownerName: owner,
    caption: '',
    mediaType: 'image',
    mediaUrl: 'local://$id.jpg',
    verified: true,
    sponsored: false,
    rating: 0,
    services: const ['Cut'],
    locationLabel: 'Atlanta, GA',
  );
}
