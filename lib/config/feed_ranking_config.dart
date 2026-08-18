/// Central ranking weights and time windows for Feeds (New / Trending / Recommended)
/// and the VUE discovery mosaic.
///
/// Keep all tunable feed-ranking constants here so SQL RPCs and client fallbacks
/// stay aligned. Server RPCs in `20260906_feeds_trending_recommended_interactions.sql`
/// mirror these values.
class FeedRankingConfig {
  FeedRankingConfig._();

  /// Activity window for Trending momentum (~48 hours).
  static const Duration trendingWindow = Duration(hours: 48);

  /// Soft age decay horizon for Trending (hours).
  static const double trendingAgeDecayHours = 48.0;

  /// Trending signal weights (match SQL `fetch_trending_feed`).
  static const double weightViews = 0.1;
  static const double weightLikes = 1.0;
  static const double weightComments = 2.0;
  static const double weightSaves = 3.0;
  static const double weightShares = 4.0;
  static const double weightMeaningfulWatch = 0.002; // per ms of watch time
  static const double weightRepostsAsShares = 4.0;

  /// Age decay multiplier applied as `ageHours / trendingAgeDecayHours * ageDecayFactor`.
  static const double ageDecayFactor = 25.0;

  /// Recommended affinity weights.
  static const double recFollowBoost = 40.0;
  static const double recGroupBoost = 28.0;
  static const double recCommunityBoost = 24.0;
  static const double recEventBoost = 18.0;
  static const double recSaveBoost = 22.0;
  static const double recShareBoost = 20.0;
  static const double recSparkBoost = 8.0;
  static const double recCommentBoost = 10.0;
  static const double recWatchBoost = 16.0;
  static const double recRepeatInterestBoost = 12.0;
  static const double recSeenPenalty = 18.0;
  static const double recSkipPenalty = 30.0;
  static const double recHidePenalty = 50.0;
  static const double recReportPenalty = 80.0;
  static const double recSameCreatorPenalty = 14.0;

  /// Max posts from the same author in one Recommended page.
  static const int recommendedMaxPerCreator = 2;

  /// Default page size for cursor / limit pagination.
  static const int defaultPageSize = 20;

  /// Feed source labels for impressions / interactions.
  static const String sourceMain = 'main';
  static const String sourceCommunities = 'community';
  static const String sourceGroups = 'group';
  static const String sourceTrending = 'trending';
  static const String sourceNew = 'new';
  static const String sourceRecommended = 'recommended';

  // --- VUE mosaic (Instagram Reels-style ranked shuffle) ---

  /// Max contribution from seeded hash noise so order changes each visit
  /// while still favoring stronger tiles.
  static const double vueSeedVariance = 28.0;

  static const double vueSponsoredBoost = 22.0;
  static const double vueVerifiedBoost = 10.0;
  static const double vueLiveBoost = 14.0;
  static const double vueRatingBoost = 6.0; // per rating point (0–5)
  static const double vueOwnContentBoost = 40.0;
  static const double vueNewsBoost = 8.0;
  static const double vueMemberBoost = 4.0;

  /// Soft penalty for stacking the same creator back-to-back in ranked order.
  static const double vueSameCreatorPenalty = 12.0;

  /// Blend of recent (48h) vs lifetime engagement for VUE trending ranks.
  /// Recent velocity is the primary signal; lifetime is a light tie-break.
  static const double vueRecentWeight = 1.0;
  static const double vueLifetimeWeight = 0.18;

  /// Per valid video play session (not unique viewers, not autoplay restarts).
  static const double vuePlayWeight = 0.8;

  /// How much engagement may nudge the For You mosaic shuffle.
  static const double vueEngagementMix = 0.25;
}
