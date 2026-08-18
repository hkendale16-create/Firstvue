import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/services/hashtag_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HashtagQuery.tokens', () {
    test('splits phrases and adds a joined prefix', () {
      expect(
        HashtagQuery.tokens('Atlanta nightlife'),
        containsAll(['atlanta', 'nightlife', 'atlantanightlife']),
      );
    });

    test('strips hash marks and ignores short fragments', () {
      expect(HashtagQuery.tokens('#Atlanta'), ['atlanta']);
      expect(HashtagQuery.tokens('a #b'), isEmpty);
    });

    test('keeps underscores and drops punctuation', () {
      expect(
        HashtagQuery.tokens('First_Vue night-life'),
        containsAll(['first_vue', 'night', 'life']),
      );
    });
  });

  group('HashtagQuery.sortTop', () {
    test('ranks by sparks then reposts then recency', () {
      CommunityNewsPost post({
        required String id,
        required int sparks,
        int reposts = 0,
        required DateTime createdAt,
      }) {
        return CommunityNewsPost(
          id: id,
          body: id,
          authorId: 'u1',
          authorName: 'Kendale',
          businessName: null,
          createdAt: createdAt,
          isMine: false,
          sparkCount: sparks,
          sparkedByMe: false,
          savedByMe: false,
          repostCount: reposts,
          publishDestination: PublishDestination.feed,
        );
      }

      final ranked = HashtagQuery.sortTop([
        post(
          id: 'older-hot',
          sparks: 2,
          createdAt: DateTime(2026, 8, 1),
        ),
        post(
          id: 'newer-hotter',
          sparks: 4,
          createdAt: DateTime(2026, 8, 10),
        ),
        post(
          id: 'reposts',
          sparks: 1,
          reposts: 2,
          createdAt: DateTime(2026, 8, 2),
        ),
      ]);

      expect(
        ranked.map((post) => post.id).toList(),
        ['reposts', 'newer-hotter', 'older-hot'],
      );
    });
  });
}
