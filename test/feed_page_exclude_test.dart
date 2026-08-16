import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityNewsPost _post(
  String id, {
  PublishDestination destination = PublishDestination.feed,
}) {
  return CommunityNewsPost(
    id: id,
    body: 'body',
    authorId: 'author',
    authorName: 'Author',
    businessName: null,
    createdAt: DateTime.utc(2026, 1, 1),
    isMine: false,
    sparkCount: 0,
    sparkedByMe: false,
    savedByMe: false,
    publishDestination: destination,
  );
}

void main() {
  test('pageAfterExclude skips seen ids and respects limit', () {
    final page = CommunityNewsService.pageAfterExclude(
      [_post('a'), _post('b'), _post('c'), _post('d')],
      excludeIds: const ['a', 'c'],
      limit: 1,
    );
    expect(page.map((p) => p.id), ['b']);
  });

  test('pageAfterExclude can require home-visible destinations', () {
    final page = CommunityNewsService.pageAfterExclude(
      [
        _post('vue', destination: PublishDestination.vue),
        _post('feed'),
        _post('both', destination: PublishDestination.feedAndVue),
      ],
      excludeIds: const [],
      limit: 10,
      homeOnly: true,
    );
    expect(page.map((p) => p.id), ['feed', 'both']);
  });
}
