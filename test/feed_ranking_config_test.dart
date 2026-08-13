import 'package:firstvue/config/feed_ranking_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FeedRankingConfig exposes trending formula weights', () {
    expect(FeedRankingConfig.trendingWindow, const Duration(hours: 48));
    expect(FeedRankingConfig.weightViews, 0.1);
    expect(FeedRankingConfig.weightLikes, 1.0);
    expect(FeedRankingConfig.weightComments, 2.0);
    expect(FeedRankingConfig.weightSaves, 3.0);
    expect(FeedRankingConfig.weightShares, 4.0);
    expect(FeedRankingConfig.recommendedMaxPerCreator, 2);
    expect(FeedRankingConfig.sourceTrending, 'trending');
    expect(FeedRankingConfig.sourceNew, 'new');
    expect(FeedRankingConfig.sourceRecommended, 'recommended');
  });
}
