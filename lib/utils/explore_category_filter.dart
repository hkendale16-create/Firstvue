import '../services/community_news_service.dart';

enum ExploreCategory {
  businesses,
  people,
  events,
  thingsToDo,
  food,
  bars,
  rentals,
}

class ExploreCategoryFilter {
  ExploreCategoryFilter._();

  static bool matches(CommunityNewsPost post, ExploreCategory category) {
    final type = post.resolvedAuthorProfileType;
    final businessType = (post.businessType ?? '').toLowerCase();
    final body = post.body.toLowerCase();
    final hasActivitySignal =
        body.contains('#thingstodo') ||
        body.contains('things to do') ||
        businessType.contains('activity') ||
        businessType.contains('attraction') ||
        businessType.contains('recreation') ||
        businessType.contains('entertainment') ||
        businessType.contains('experience');
    final hasRentalSignal =
        type == 'rental' ||
        businessType.contains('rental') ||
        body.contains('#rental') ||
        body.contains('for rent');

    return switch (category) {
      ExploreCategory.businesses =>
        type == 'business' || post.businessId != null,
      ExploreCategory.people => type == 'user' && post.businessId == null,
      ExploreCategory.events => type == 'event' || post.eventId != null,
      ExploreCategory.thingsToDo =>
        hasActivitySignal ||
            type == 'activity' ||
            (type == 'business' &&
                (businessType.contains('activity') ||
                    businessType.contains('attraction') ||
                    businessType.contains('recreation') ||
                    businessType.contains('entertainment') ||
                    businessType.contains('experience'))),
      ExploreCategory.food =>
        businessType.contains('restaurant') ||
            businessType.contains('food') ||
            businessType.contains('dining') ||
            businessType.contains('cafe') ||
            businessType.contains('café') ||
            businessType.contains('bakery') ||
            businessType.contains('cater') ||
            businessType.contains('bistro') ||
            businessType.contains('truck'),
      ExploreCategory.bars =>
        businessType.contains('bar') ||
            businessType.contains('lounge') ||
            businessType.contains('club') ||
            businessType.contains('brewery') ||
            businessType.contains('nightlife') ||
            businessType.contains('pub'),
      ExploreCategory.rentals => hasRentalSignal,
    };
  }
}
