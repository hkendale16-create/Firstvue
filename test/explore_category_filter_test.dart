import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/utils/explore_category_filter.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityNewsPost _post({
  String body = 'hello',
  String? authorProfileType,
  String? businessId,
  String? businessType,
  String? eventId,
}) {
  return CommunityNewsPost(
    id: 'p1',
    body: body,
    authorId: 'u1',
    authorName: 'Ada',
    authorProfileType: authorProfileType,
    businessId: businessId,
    businessName: businessType,
    businessType: businessType,
    eventId: eventId,
    createdAt: DateTime.utc(2026, 8, 1),
    isMine: false,
    sparkCount: 0,
    sparkedByMe: false,
    savedByMe: false,
    publishDestination: PublishDestination.feed,
  );
}

void main() {
  test('Explore categories do not share the same unfiltered match', () {
    final food = _post(
      authorProfileType: 'business',
      businessId: 'b1',
      businessType: 'Restaurant',
    );
    final bar = _post(
      authorProfileType: 'business',
      businessId: 'b2',
      businessType: 'Bar',
    );
    final activity = _post(
      body: 'Saturday hike #thingstodo',
      authorProfileType: 'business',
      businessId: 'b3',
      businessType: 'Activity Provider',
    );
    final rental = _post(
      body: 'Studio for rent downtown',
      authorProfileType: 'rental',
    );

    expect(ExploreCategoryFilter.matches(food, ExploreCategory.food), isTrue);
    expect(ExploreCategoryFilter.matches(food, ExploreCategory.bars), isFalse);
    expect(ExploreCategoryFilter.matches(bar, ExploreCategory.bars), isTrue);
    expect(ExploreCategoryFilter.matches(bar, ExploreCategory.food), isFalse);
    expect(
      ExploreCategoryFilter.matches(activity, ExploreCategory.thingsToDo),
      isTrue,
    );
    expect(
      ExploreCategoryFilter.matches(activity, ExploreCategory.food),
      isFalse,
    );
    expect(
      ExploreCategoryFilter.matches(rental, ExploreCategory.rentals),
      isTrue,
    );
    expect(
      ExploreCategoryFilter.matches(rental, ExploreCategory.people),
      isFalse,
    );
  });
}
