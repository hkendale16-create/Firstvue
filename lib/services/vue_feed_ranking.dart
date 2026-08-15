import '../config/feed_ranking_config.dart';
import '../services/discovery_feed_service.dart';

/// Deterministic 0..1 hash from media id + seed (stable for a session).
double vueFeedSeedNoise(String mediaId, double seed) {
  final key = '$mediaId:${seed.toStringAsFixed(6)}';
  var hash = 2166136261;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return (hash % 10000) / 10000.0;
}

double scoreVueFeedItem(
  DiscoveryFeedItem item, {
  required double seed,
  String? viewerId,
  String? previousCreatorId,
}) {
  var score = vueFeedSeedNoise(item.mediaId, seed) *
      FeedRankingConfig.vueSeedVariance;

  if (item.sponsored) score += FeedRankingConfig.vueSponsoredBoost;
  if (item.verified) score += FeedRankingConfig.vueVerifiedBoost;
  if (item.liveNow) score += FeedRankingConfig.vueLiveBoost;
  score += item.rating.clamp(0, 5) * FeedRankingConfig.vueRatingBoost;

  if (item.newsPostId != null) {
    score += FeedRankingConfig.vueNewsBoost;
  } else if (item.isMember) {
    score += FeedRankingConfig.vueMemberBoost;
  }

  if (viewerId != null &&
      viewerId.isNotEmpty &&
      item.ownerId == viewerId) {
    score += FeedRankingConfig.vueOwnContentBoost;
  }

  if (previousCreatorId != null &&
      previousCreatorId.isNotEmpty &&
      item.creatorId == previousCreatorId) {
    score -= FeedRankingConfig.vueSameCreatorPenalty;
  }

  return score;
}

/// Rank + shuffle VUE tiles like Instagram Reels: quality signals plus a
/// fresh seed so each access (and pull-to-refresh) yields a different order.
List<DiscoveryFeedItem> rankVueFeedItems(
  List<DiscoveryFeedItem> items, {
  required double seed,
  String? viewerId,
  VueFeedMode mode = VueFeedMode.forYou,
}) {
  if (items.length <= 1) return List<DiscoveryFeedItem>.from(items);

  final remaining = List<DiscoveryFeedItem>.from(items);
  final ranked = <DiscoveryFeedItem>[];
  String? previousCreator;

  while (remaining.isNotEmpty) {
    remaining.sort((a, b) {
      final scoreA = scoreVueFeedItem(
        a,
        seed: seed,
        viewerId: viewerId,
        previousCreatorId: previousCreator,
      );
      final scoreB = scoreVueFeedItem(
        b,
        seed: seed,
        viewerId: viewerId,
        previousCreatorId: previousCreator,
      );
      // Mode nudges: trending leans harder on rating; nearby keeps seed mix.
      final modeBiasA = switch (mode) {
        VueFeedMode.trending => a.rating * 10.0,
        VueFeedMode.nearby => a.sponsored ? 4.0 : 0.0,
        VueFeedMode.forYou => 0.0,
      };
      final modeBiasB = switch (mode) {
        VueFeedMode.trending => b.rating * 10.0,
        VueFeedMode.nearby => b.sponsored ? 4.0 : 0.0,
        VueFeedMode.forYou => 0.0,
      };
      final cmp = (scoreB + modeBiasB).compareTo(scoreA + modeBiasA);
      if (cmp != 0) return cmp;
      return a.mediaId.compareTo(b.mediaId);
    });
    final next = remaining.removeAt(0);
    ranked.add(next);
    previousCreator = next.creatorId;
  }

  return ranked;
}
