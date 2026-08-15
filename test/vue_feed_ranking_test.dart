import 'package:firstvue/services/discovery_feed_service.dart';
import 'package:firstvue/services/vue_feed_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

DiscoveryFeedItem _item({
  required String id,
  String owner = 'u1',
  double rating = 0,
  bool sponsored = false,
  bool verified = false,
  bool liveNow = false,
  VueFeedSource source = VueFeedSource.business,
  String? newsPostId,
}) {
  return DiscoveryFeedItem(
    mediaId: id,
    businessId: source == VueFeedSource.business ? 'b-$id' : '',
    businessName: 'Biz $id',
    businessType: 'Local',
    ownerId: owner,
    ownerName: 'Owner $owner',
    caption: 'Caption $id',
    mediaType: 'image',
    mediaUrl: 'https://example.com/$id.jpg',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rating: rating,
    services: const [],
    verified: verified,
    sponsored: sponsored,
    liveNow: liveNow,
    source: source,
    newsPostId: newsPostId,
  );
}

void main() {
  test('same seed produces identical order', () {
    final items = [
      _item(id: 'a', rating: 4),
      _item(id: 'b', rating: 2, sponsored: true),
      _item(id: 'c', rating: 5, verified: true),
      _item(id: 'd', owner: 'u2', rating: 3),
    ];
    final first = rankVueFeedItems(items, seed: 42.5);
    final second = rankVueFeedItems(items, seed: 42.5);
    expect(first.map((e) => e.mediaId).toList(),
        second.map((e) => e.mediaId).toList());
  });

  test('different seeds usually change order', () {
    final items = [
      for (var i = 0; i < 12; i++)
        _item(id: 'm$i', owner: 'u$i', rating: (i % 5).toDouble()),
    ];
    final a = rankVueFeedItems(items, seed: 1.0).map((e) => e.mediaId).join();
    final b = rankVueFeedItems(items, seed: 99.0).map((e) => e.mediaId).join();
    expect(a, isNot(equals(b)));
  });

  test('sponsored and high rating tend to rank above plain tiles', () {
    final plain = _item(id: 'plain', rating: 0);
    final strong = _item(id: 'strong', rating: 5, sponsored: true, verified: true);
    final ranked = rankVueFeedItems([plain, strong], seed: 7.0);
    expect(ranked.first.mediaId, 'strong');
  });

  test('viewer own content receives a boost', () {
    final mine = _item(id: 'mine', owner: 'me', rating: 0);
    final other = _item(id: 'other', owner: 'them', rating: 1);
    final ranked = rankVueFeedItems(
      [other, mine],
      seed: 3.0,
      viewerId: 'me',
    );
    expect(ranked.first.mediaId, 'mine');
  });

  test('seed noise is deterministic and bounded', () {
    final n1 = vueFeedSeedNoise('abc', 10.0);
    final n2 = vueFeedSeedNoise('abc', 10.0);
    final n3 = vueFeedSeedNoise('abc', 11.0);
    expect(n1, n2);
    expect(n1, inInclusiveRange(0.0, 1.0));
    expect(n1, isNot(equals(n3)));
  });
}
