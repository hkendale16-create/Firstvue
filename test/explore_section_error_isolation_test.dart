import 'package:firstvue/models/explore_item.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_media_service.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/config/media_config.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityNewsPost _post(String id) {
  return CommunityNewsPost(
    id: id,
    body: 'hello',
    authorId: 'u1',
    authorName: 'Ada',
    authorUsername: 'ada',
    businessName: null,
    createdAt: DateTime.utc(2026, 8, 1),
    isMine: false,
    viewerFollowsAuthor: false,
    sparkCount: 0,
    sparkedByMe: false,
    savedByMe: false,
    visibility: 'public',
    publishDestination: PublishDestination.feed,
    media: const [
      CommunityNewsMediaItem(
        id: 'm1',
        storagePath: 'posts/a.jpg',
        signedUrl: 'https://example.com/a.jpg',
        storageProvider: MediaStorageProvider.supabase,
        mediaType: 'image',
      ),
    ],
  );
}

void main() {
  test('ExploreSectionStore surfaces section errors independently', () async {
    final store = ExploreSectionStore(pageSize: 8);
    await store.load(ExploreSection.people, ({
      required section,
      beforeCreatedAt,
      beforeId,
    }) async {
      throw StateError('people boom');
    });
    expect(store.of(ExploreSection.people).error, isNotNull);
    expect(store.of(ExploreSection.people).loading, isFalse);

    await store.load(ExploreSection.businesses, ({
      required section,
      beforeCreatedAt,
      beforeId,
    }) async {
      return ExplorePageResult(
        items: [
          ExploreItem.entityItem(
            section: ExploreSection.businesses,
            entity: const ExploreEntityCard(
              id: 'b1',
              kind: 'business',
              name: 'Studio',
            ),
          ),
        ],
        hasMore: false,
      );
    });
    expect(store.of(ExploreSection.businesses).error, isNull);
    expect(store.of(ExploreSection.businesses).items, isNotEmpty);
    // People failure must not wipe or block Businesses.
    expect(store.of(ExploreSection.people).error, isNotNull);
  });

  test('entity-only page does not advertise post pagination', () {
    // Mirrors ExploreFeedService._page cursor rules without hitting network.
    final items = [
      ExploreItem.entityItem(
        section: ExploreSection.businesses,
        entity: const ExploreEntityCard(
          id: 'b1',
          kind: 'business',
          name: 'A',
        ),
      ),
      ExploreItem.entityItem(
        section: ExploreSection.businesses,
        entity: const ExploreEntityCard(
          id: 'b2',
          kind: 'business',
          name: 'B',
        ),
      ),
    ];
    DateTime? cursorCreatedAt;
    String? cursorId;
    for (var i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      if (item.post != null) {
        cursorCreatedAt = item.post!.createdAt;
        cursorId = item.post!.id;
        break;
      }
    }
    final canPaginatePosts = cursorId != null && cursorCreatedAt != null;
    expect(canPaginatePosts, isFalse);

    final withPost = [
      ...items,
      ExploreItem.postItem(
        section: ExploreSection.businesses,
        post: _post('p1'),
      ),
    ];
    for (var i = withPost.length - 1; i >= 0; i--) {
      final item = withPost[i];
      if (item.post != null) {
        cursorCreatedAt = item.post!.createdAt;
        cursorId = item.post!.id;
        break;
      }
    }
    expect(cursorId, 'p1');
    expect(cursorCreatedAt, isNotNull);
  });
}
