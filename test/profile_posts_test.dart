import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/services/profile_activity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityNewsPost', () {
    test('copyWith preserves unchanged fields', () {
      final createdAt = DateTime(2026, 8, 12);
      final post = CommunityNewsPost(
        id: 'post-1',
        body: 'Hello community',
        authorId: 'user-1',
        authorName: 'Kendale',
        businessName: null,
        createdAt: createdAt,
        isMine: true,
        sparkCount: 2,
        sparkedByMe: false,
        savedByMe: false,
      );

      final updated = post.copyWith(
        sparkedByMe: true,
        sparkCount: 3,
      );

      expect(updated.id, 'post-1');
      expect(updated.body, 'Hello community');
      expect(updated.sparkedByMe, isTrue);
      expect(updated.sparkCount, 3);
      expect(updated.commentsMediaId, 'news-post:post-1');
    });
  });

  group('ProfileActivityService.formatRelativeTime', () {
    test('returns minutes ago for recent activity', () {
      final label = ProfileActivityService.formatRelativeTime(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(label, '5 minutes ago');
    });
  });
}
