import 'package:firstvue/config/media_config.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_media_service.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/utils/explore_category_filter.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityNewsPost _post({
  String body = 'hello',
  String? authorProfileType,
  String? businessId,
  String? businessType,
  String? eventId,
  String? industrySlug,
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
    industrySlug: industrySlug,
    eventId: eventId,
    createdAt: DateTime.utc(2026, 8, 1),
    isMine: false,
    sparkCount: 0,
    sparkedByMe: false,
    savedByMe: false,
    publishDestination: PublishDestination.feed,
    media: const [
      CommunityNewsMediaItem(
        id: 'm1',
        storagePath: 'posts/a.jpg',
        signedUrl: 'https://example.com/a.jpg',
        storageProvider: MediaStorageProvider.supabase,
        mediaType: 'image',
      ),
    ],
  );
}

void main() {
  test('Explore categories do not share the same unfiltered match', () {
    final food = _post(
      authorProfileType: 'business',
      businessId: 'b1',
      businessType: 'Restaurant',
      industrySlug: 'restaurant',
    );
    final bar = _post(
      authorProfileType: 'business',
      businessId: 'b2',
      businessType: 'Bar',
      industrySlug: 'bar',
    );
    final activity = _post(
      body: 'Saturday hike #thingstodo',
      authorProfileType: 'business',
      businessId: 'b3',
      businessType: 'Activity Provider',
      industrySlug: 'activity-provider',
    );
    final rental = _post(
      body: 'Studio for rent downtown',
      authorProfileType: 'business',
      businessId: 'b4',
      businessType: 'Rentals',
      industrySlug: 'rentals',
    );

    expect(ExploreCategoryFilter.matches(food, ExploreSection.food), isTrue);
    expect(ExploreCategoryFilter.matches(food, ExploreSection.bars), isFalse);
    expect(ExploreCategoryFilter.matches(bar, ExploreSection.bars), isTrue);
    expect(ExploreCategoryFilter.matches(bar, ExploreSection.food), isFalse);
    expect(
      ExploreCategoryFilter.matches(activity, ExploreSection.thingsToDo),
      isTrue,
    );
    expect(
      ExploreCategoryFilter.matches(activity, ExploreSection.food),
      isFalse,
    );
    expect(
      ExploreCategoryFilter.matches(rental, ExploreSection.rentals),
      isTrue,
    );
    expect(
      ExploreCategoryFilter.matches(rental, ExploreSection.people),
      isFalse,
    );
  });
}
