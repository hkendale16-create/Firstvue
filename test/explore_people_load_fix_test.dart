import 'package:firstvue/data/industry_catalog.dart';
import 'package:firstvue/models/explore_item.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/services/explore_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IndustryCatalog unknown free-text slugs do not recurse forever', () {
    expect(IndustryCatalog.bySlug('bartender').slug, 'bar');
    expect(IndustryCatalog.bySlug('unknown-xyz').slug, 'general-business');
    expect(IndustryCatalog.fromDisplayType('Night Club').slug, 'bar');
  });

  test('ExploreSectionStore recovers when fetcher throws', () async {
    final store = ExploreSectionStore(pageSize: 8);
    await store.load(ExploreSection.people, ({
      required section,
      beforeCreatedAt,
      beforeId,
    }) async {
      throw StateError('boom');
    });
    expect(store.of(ExploreSection.people).loading, isFalse);
    expect(store.of(ExploreSection.people).error, isNotNull);
    expect(store.of(ExploreSection.people).items, isEmpty);

    await store.load(
      ExploreSection.people,
      ({required section, beforeCreatedAt, beforeId}) async {
        return ExplorePageResult(
          items: [
            ExploreItem.profileItem(
              profile: const ExploreProfileCard(
                id: 'u1',
                displayName: 'Kendale',
                handle: '@kendale',
              ),
            ),
          ],
          hasMore: false,
        );
      },
      refresh: true,
    );
    expect(store.of(ExploreSection.people).error, isNull);
    expect(store.of(ExploreSection.people).items, isNotEmpty);
  });

  test('ExploreFeedService.pageSize is stable', () {
    expect(ExploreFeedService.pageSize, greaterThan(0));
  });
}
