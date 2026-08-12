import 'package:shared_preferences/shared_preferences.dart';

import 'trending_businesses_service.dart';

class RecommendationsService {
  RecommendationsService._();

  static const _recentCategoriesKey = 'firstvue_recent_categories';

  static Future<void> recordCategoryVisit(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_recentCategoriesKey) ?? [];
    final updated = [category, ...existing.where((item) => item != category)]
        .take(6)
        .toList();
    await prefs.setStringList(_recentCategoriesKey, updated);
  }

  static Future<List<TrendingBusiness>> fetchYouMightLike({int limit = 6}) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = prefs.getStringList(_recentCategoriesKey) ?? const [];
    final businesses = await TrendingBusinessesService.fetchRecommendedNearYou(
      limit: limit * 2,
    );
    if (categories.isEmpty || businesses.isEmpty) {
      return businesses.take(limit).toList();
    }

    final scored = businesses.map((business) {
      final haystack = [
        business.name,
        ...business.services,
      ].join(' ').toLowerCase();
      var score = business.reviewCount.toDouble();
      for (final category in categories) {
        if (haystack.contains(category.toLowerCase())) score += 12;
      }
      return (business: business, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((entry) => entry.business).toList();
  }
}
