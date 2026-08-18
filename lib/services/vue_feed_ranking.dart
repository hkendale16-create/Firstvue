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

  score += vueTrendingScore(item) * FeedRankingConfig.vueEngagementMix;

  return score;
}

/// Engagement + recency score used for the 🔥 trending rank badge.
/// Recent (48h) activity outweighs lifetime totals; raw views alone cannot
/// keep stale media at #1.
double vueTrendingScore(DiscoveryFeedItem item, {DateTime? now}) {
  double mix(int recent, int lifetime, double weight) {
    return recent * weight * FeedRankingConfig.vueRecentWeight +
        lifetime * weight * FeedRankingConfig.vueLifetimeWeight;
  }

  var score = 0.0;
  score += mix(
    item.recentViewsCount,
    item.viewsCount,
    FeedRankingConfig.weightViews,
  );
  score += mix(
    item.recentLikesCount,
    item.likesCount,
    FeedRankingConfig.weightLikes,
  );
  score += mix(
    item.recentCommentsCount,
    item.commentsCount,
    FeedRankingConfig.weightComments,
  );
  score += mix(
    item.recentSavesCount,
    item.savesCount,
    FeedRankingConfig.weightSaves,
  );
  score += mix(
    item.recentSharesCount,
    item.sharesCount,
    FeedRankingConfig.weightShares,
  );
  score += mix(
    item.recentPlaysCount,
    item.playsCount,
    FeedRankingConfig.vuePlayWeight,
  );

  final createdAt = item.createdAt;
  if (createdAt != null) {
    final clock = now ?? DateTime.now();
    final ageHours = clock.difference(createdAt).inSeconds / 3600.0;
    if (ageHours > 0) {
      score -= (ageHours / FeedRankingConfig.trendingAgeDecayHours) *
          FeedRankingConfig.ageDecayFactor;
    }
  }
  return score;
}

/// Assigns 1-based trending ranks from engagement velocity. Mosaic / For You
/// order is left unchanged — only the badge number is rewritten.
List<DiscoveryFeedItem> assignVueTrendingRanks(
  List<DiscoveryFeedItem> items, {
  DateTime? now,
}) {
  if (items.isEmpty) return items;
  final ranked = List<DiscoveryFeedItem>.from(items);
  ranked.sort((a, b) {
    final cmp = vueTrendingScore(b, now: now)
        .compareTo(vueTrendingScore(a, now: now));
    if (cmp != 0) return cmp;
    final created = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    if (created != 0) return created;
    return a.mediaId.compareTo(b.mediaId);
  });
  final ranks = <String, int>{
    for (var i = 0; i < ranked.length; i++) ranked[i].mediaId: i + 1,
  };
  return [
    for (final item in items)
      item.copyWith(trendingRank: ranks[item.mediaId] ?? item.trendingRank),
  ];
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
        VueFeedMode.trending => vueTrendingScore(a) + a.rating * 2.0,
        VueFeedMode.nearby => a.sponsored ? 4.0 : 0.0,
        VueFeedMode.forYou => 0.0,
      };
      final modeBiasB = switch (mode) {
        VueFeedMode.trending => vueTrendingScore(b) + b.rating * 2.0,
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
