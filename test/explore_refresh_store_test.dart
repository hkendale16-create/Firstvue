import 'package:firstvue/models/explore_item.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pull refresh reloads even when a prior load left loading=true', () async {
    final store = ExploreSectionStore(pageSize: 8);
    store.seed(
      ExploreSection.businesses,
      const ExploreSectionSnapshot(
        items: [],
        loading: true,
      ),
    );

    var fetches = 0;
    await store.load(
      ExploreSection.businesses,
      ({required section, beforeCreatedAt, beforeId}) async {
        fetches += 1;
        return ExplorePageResult(
          items: [
            ExploreItem.entityItem(
              section: ExploreSection.businesses,
              entity: const ExploreEntityCard(
                id: 'b1',
                kind: 'business',
                name: 'Demo Biz',
              ),
            ),
          ],
          hasMore: false,
        );
      },
      refresh: true,
    );

    expect(fetches, 1);
    expect(store.of(ExploreSection.businesses).loading, isFalse);
    expect(store.of(ExploreSection.businesses).items, hasLength(1));
  });

  test('refresh supersedes an in-flight load', () async {
    final store = ExploreSectionStore(pageSize: 8);
    var fetches = 0;

    final first = store.load(
      ExploreSection.people,
      ({required section, beforeCreatedAt, beforeId}) async {
        fetches += 1;
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return ExplorePageResult(
          items: [
            ExploreItem.profileItem(
              profile: const ExploreProfileCard(
                id: 'old',
                displayName: 'Old',
              ),
            ),
          ],
          hasMore: false,
        );
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.load(
      ExploreSection.people,
      ({required section, beforeCreatedAt, beforeId}) async {
        fetches += 1;
        return ExplorePageResult(
          items: [
            ExploreItem.profileItem(
              profile: const ExploreProfileCard(
                id: 'new',
                displayName: 'New',
              ),
            ),
          ],
          hasMore: false,
        );
      },
      refresh: true,
    );
    await first;

    expect(fetches, 2);
    expect(store.of(ExploreSection.people).items.single.id, 'profile:new');
    expect(store.of(ExploreSection.people).loading, isFalse);
  });
}
