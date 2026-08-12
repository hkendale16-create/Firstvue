import 'package:firstvue/services/community_news_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CommunityNewsPost keeps community context fields', () {
    final post = CommunityNewsPost(
      id: 'p1',
      body: 'Hello group',
      authorId: 'u1',
      authorName: 'Kendale',
      authorUsername: 'kendale',
      businessName: null,
      communityId: 'c1',
      communityName: 'Atlanta Entrepreneurs',
      communityImageUrl: 'https://example.com/g.png',
      createdAt: DateTime(2026, 8, 12),
      isMine: true,
      sparkCount: 0,
      sparkedByMe: false,
      savedByMe: false,
    );

    expect(post.communityId, 'c1');
    expect(post.communityName, 'Atlanta Entrepreneurs');
    expect(post.copyWith(communityName: 'Updated').communityName, 'Updated');
  });
}
