import 'package:firstvue/services/community_news_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityNewsService.resolveDisplayBody', () {
    test('hides misleading teaser for author when media exists', () {
      final body = CommunityNewsService.resolveDisplayBody(
        rawBody: 'Follow for more details',
        visibility: 'public',
        isMine: true,
        followsAuthor: false,
        hasMedia: true,
      );
      expect(body, isEmpty);
    });

    test('shows honest follow prompt for gated posts', () {
      final body = CommunityNewsService.resolveDisplayBody(
        rawBody: 'Follow for more details',
        visibility: 'followers',
        isMine: false,
        followsAuthor: false,
        hasMedia: false,
      );
      expect(body, 'Follow this member to see the full post.');
    });

    test('preserves normal post text', () {
      const text = 'Grand opening this Saturday at noon!';
      final body = CommunityNewsService.resolveDisplayBody(
        rawBody: text,
        visibility: 'public',
        isMine: false,
        followsAuthor: false,
        hasMedia: false,
      );
      expect(body, text);
    });
  });

  group('CommunityNewsPost community attribution', () {
    test('isCommunityPost is true when communityId is set', () {
      final post = CommunityNewsPost(
        id: '1',
        body: 'Hello community',
        authorId: 'a',
        authorName: 'John Smith',
        authorUsername: 'johnsmith',
        businessName: null,
        communityId: 'c1',
        communityName: 'Atlanta Entrepreneurs',
        createdAt: DateTime.utc(2026, 1, 1),
        isMine: false,
        sparkCount: 0,
        sparkedByMe: false,
        savedByMe: false,
      );
      expect(post.isCommunityPost, isTrue);
      expect(post.communityName, 'Atlanta Entrepreneurs');
    });
  });
}
