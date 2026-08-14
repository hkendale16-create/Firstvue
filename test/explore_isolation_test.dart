import 'package:firstvue/config/media_config.dart';
import 'package:firstvue/models/explore_item.dart';
import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_media_service.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/utils/explore_category_filter.dart';
import 'package:firstvue/widgets/firstvue_bottom_nav.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityNewsPost _post({
  String id = 'p1',
  String body = 'hello',
  String? authorProfileType,
  String? businessId,
  String? businessType,
  String? industrySlug,
  List<String> secondaryIndustrySlugs = const [],
  List<String> services = const [],
  String? eventId,
  String? communityId,
  String? rentalId,
  String? publishCategory,
  String visibility = 'public',
  bool isMine = false,
  bool viewerFollowsAuthor = false,
  bool withMedia = true,
}) {
  return CommunityNewsPost(
    id: id,
    body: body,
    authorId: 'u1',
    authorName: 'Ada',
    authorUsername: 'ada',
    authorProfileType: authorProfileType,
    businessId: businessId,
    businessName: businessType,
    businessType: businessType,
    industrySlug: industrySlug,
    secondaryIndustrySlugs: secondaryIndustrySlugs,
    businessServices: services,
    eventId: eventId,
    communityId: communityId,
    rentalId: rentalId,
    publishCategory: publishCategory,
    createdAt: DateTime.utc(2026, 8, 1),
    isMine: isMine,
    viewerFollowsAuthor: viewerFollowsAuthor,
    sparkCount: 0,
    sparkedByMe: false,
    savedByMe: false,
    visibility: visibility,
    publishDestination: PublishDestination.feed,
    media: withMedia
        ? const [
            CommunityNewsMediaItem(
              id: 'm1',
              storagePath: 'posts/a.jpg',
              signedUrl: 'https://example.com/a.jpg',
              storageProvider: MediaStorageProvider.supabase,
              mediaType: 'image',
            ),
          ]
        : const [],
  );
}

void main() {
  group('authenticated landing', () {
    test('root and vue routes select VUE', () {
      expect(FirstVueBottomNav.indexForRoute('/'), FirstVueBottomNav.vueIndex);
      expect(FirstVueBottomNav.indexForRoute('/vue'), FirstVueBottomNav.vueIndex);
      expect(FirstVueBottomNav.indexForRoute(''), FirstVueBottomNav.vueIndex);
    });

    test('signed-in tab routes map without discarding deep-link stacks', () {
      expect(
        FirstVueBottomNav.indexForRoute('/explore'),
        FirstVueBottomNav.exploreIndex,
      );
      expect(
        FirstVueBottomNav.indexForRoute('/feeds'),
        FirstVueBottomNav.feedsIndex,
      );
      expect(
        FirstVueBottomNav.indexForRoute('/profile'),
        FirstVueBottomNav.profileIndex,
      );
      expect(FirstVueBottomNav.indexForRoute('/settings'), isNull);
      expect(FirstVueBottomNav.indexForRoute('/messages'), isNull);
    });

    test('VUE is the default bottom-nav destination', () {
      expect(FirstVueBottomNav.vueIndex, 2);
    });
  });

  group('Explore isolation', () {
    test('personal posts appear under People only', () {
      final personal = _post(
        authorProfileType: 'user',
        body: 'Lunch at a restaurant #food',
      );
      expect(
        ExploreClassifier.sectionsFor(personal.exploreInput()),
        {ExploreSection.people},
      );
      expect(
        ExploreCategoryFilter.matches(personal, ExploreSection.people),
        isTrue,
      );
      expect(
        ExploreCategoryFilter.matches(personal, ExploreSection.food),
        isFalse,
      );
      expect(
        ExploreCategoryFilter.matches(personal, ExploreSection.businesses),
        isFalse,
      );
    });

    test('entity-authored posts do not appear under People', () {
      final business = _post(
        authorProfileType: 'business',
        businessId: 'b1',
        businessType: 'Consulting',
        industrySlug: 'consulting',
      );
      expect(
        ExploreCategoryFilter.matches(business, ExploreSection.people),
        isFalse,
      );
      expect(
        ExploreCategoryFilter.matches(business, ExploreSection.businesses),
        isTrue,
      );
    });

    test(
      'Food, Bars, Things to Do, Events, Rentals, Communities, Groups stay isolated',
      () {
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
          authorProfileType: 'business',
          businessId: 'b3',
          businessType: 'Activity Provider',
          industrySlug: 'activity-provider',
          body: 'Saturday hike #thingstodo',
        );
        final event = _post(authorProfileType: 'event', eventId: 'e1');
        final rental = _post(
          authorProfileType: 'business',
          businessId: 'b4',
          industrySlug: 'rentals',
          businessType: 'Rentals',
        );
        final group = _post(
          authorProfileType: 'community',
          communityId: 'g1',
        );
        final shared = _post(
          authorProfileType: 'business',
          businessId: 'b1',
          industrySlug: 'restaurant',
          businessType: 'Restaurant',
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
          ExploreCategoryFilter.matches(event, ExploreSection.events),
          isTrue,
        );
        expect(
          ExploreCategoryFilter.matches(event, ExploreSection.people),
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
        expect(
          ExploreCategoryFilter.matches(group, ExploreSection.groups),
          isTrue,
        );
        expect(
          ExploreCategoryFilter.matches(group, ExploreSection.people),
          isFalse,
        );

        final communitySections = ExploreClassifier.sectionsFor(
          shared.exploreInput(
            communityShare: true,
            sourceLabel: 'ATL Foodies',
          ),
        );
        expect(communitySections.contains(ExploreSection.communities), isTrue);
        expect(communitySections.contains(ExploreSection.food), isTrue);
        expect(communitySections.contains(ExploreSection.people), isFalse);
      },
    );

    test('switching posting identity changes Explore classification', () {
      final asPerson = _post(
        authorProfileType: 'user',
        body: 'Try our specials',
      );
      final asBiz = _post(
        authorProfileType: 'business',
        businessId: 'b1',
        businessType: 'Restaurant',
        industrySlug: 'restaurant',
        body: 'Try our specials',
      );
      expect(
        ExploreClassifier.sectionsFor(asPerson.exploreInput()),
        {ExploreSection.people},
      );
      expect(
        ExploreClassifier.sectionsFor(asBiz.exploreInput()),
        {ExploreSection.food},
      );
    });

    test('hashtags cannot override author identity', () {
      final personal = _post(
        authorProfileType: 'user',
        body: 'Loved that bar #nightlife #restaurant #thingstodo',
      );
      expect(
        ExploreClassifier.sectionsFor(personal.exploreInput()),
        {ExploreSection.people},
      );

      final barber = _post(
        authorProfileType: 'business',
        businessId: 'b1',
        businessType: 'Barbershop',
        industrySlug: 'barbershop',
        body: 'Fresh fade #restaurant #food',
      );
      final sections = ExploreClassifier.sectionsFor(barber.exploreInput());
      expect(sections.contains(ExploreSection.people), isFalse);
      expect(sections.contains(ExploreSection.food), isFalse);
      expect(sections.contains(ExploreSection.businesses), isTrue);
    });

    test('restricted followers-only content stays excluded for strangers', () {
      final restricted = _post(
        authorProfileType: 'user',
        visibility: 'followers',
        viewerFollowsAuthor: false,
      );
      expect(
        ExploreClassifier.sectionsFor(restricted.exploreInput()),
        isEmpty,
      );
      expect(
        ExploreCategoryFilter.matches(restricted, ExploreSection.people),
        isFalse,
      );
    });

    test('followers can see followers-only personal posts in People', () {
      final allowed = _post(
        authorProfileType: 'user',
        visibility: 'followers',
        viewerFollowsAuthor: true,
      );
      expect(
        ExploreClassifier.sectionsFor(allowed.exploreInput()),
        {ExploreSection.people},
      );
    });

    test('secondary industry can place content in multiple entity sections', () {
      final multi = _post(
        authorProfileType: 'business',
        businessId: 'b1',
        businessType: 'Restaurant',
        industrySlug: 'restaurant',
        secondaryIndustrySlugs: const ['bar'],
      );
      final sections = ExploreClassifier.sectionsFor(multi.exploreInput());
      expect(sections.contains(ExploreSection.food), isTrue);
      expect(sections.contains(ExploreSection.bars), isTrue);
      expect(sections.contains(ExploreSection.people), isFalse);
    });

    test('manual share keeps original author attribution', () {
      final post = _post(
        authorProfileType: 'business',
        businessId: 'b1',
        businessType: 'Restaurant',
        industrySlug: 'restaurant',
      );
      final item = ExploreItem.postItem(
        section: ExploreSection.communities,
        post: post,
        communityShare: true,
        originalSourceLabel: 'ATL Eats',
      );
      expect(item.originalAuthorName, 'Restaurant');
      expect(item.originalSourceLabel, 'ATL Eats');
      expect(item.post!.resolvedAuthorProfileType, 'business');
    });
  });

  group('Explore section store pagination', () {
    test('loading one section does not alter another cursor', () async {
      final store = ExploreSectionStore(pageSize: 2);
      var peopleCalls = 0;
      var foodCalls = 0;

      Future<ExplorePageResult> fetcher({
        required ExploreSection section,
        DateTime? beforeCreatedAt,
        String? beforeId,
      }) async {
        if (section == ExploreSection.people) {
          peopleCalls++;
          return ExplorePageResult(
            items: [
              ExploreItem.postItem(
                section: ExploreSection.people,
                post: _post(id: 'people-$peopleCalls-$beforeId'),
              ),
              ExploreItem.postItem(
                section: ExploreSection.people,
                post: _post(id: 'people-extra-$peopleCalls'),
              ),
            ],
            hasMore: true,
            cursorCreatedAt: DateTime.utc(2026, 8, 1),
            cursorId: 'people-$peopleCalls',
          );
        }
        foodCalls++;
        return ExplorePageResult(
          items: [
            ExploreItem.postItem(
              section: ExploreSection.food,
              post: _post(
                id: 'food-$foodCalls',
                authorProfileType: 'business',
                businessId: 'b1',
                industrySlug: 'restaurant',
              ),
            ),
          ],
          hasMore: false,
          cursorCreatedAt: DateTime.utc(2026, 7, 1),
          cursorId: 'food-$foodCalls',
        );
      }

      await store.load(ExploreSection.people, fetcher);
      await store.load(ExploreSection.food, fetcher);
      final foodBefore = store.of(ExploreSection.food);
      await store.loadMore(ExploreSection.people, fetcher);

      expect(store.of(ExploreSection.people).items.length, greaterThan(2));
      expect(store.of(ExploreSection.food).cursorId, foodBefore.cursorId);
      expect(
        store.of(ExploreSection.food).items.length,
        foodBefore.items.length,
      );
      expect(foodCalls, 1);
      expect(peopleCalls, 2);
    });

    test('cached results are never reused across sections', () async {
      final store = ExploreSectionStore();
      await store.load(ExploreSection.people, ({
        required section,
        beforeCreatedAt,
        beforeId,
      }) async {
        return ExplorePageResult(
          items: [
            ExploreItem.postItem(
              section: ExploreSection.people,
              post: _post(id: 'only-people'),
            ),
          ],
        );
      });
      expect(
        store.of(ExploreSection.people).items.single.id,
        'post:only-people',
      );
      expect(store.of(ExploreSection.food).items, isEmpty);
    });

    test('post items carry a post id for direct navigation', () {
      final item = ExploreItem.postItem(
        section: ExploreSection.people,
        post: _post(id: 'post-99'),
      );
      expect(item.kind, ExploreItemKind.post);
      expect(item.post!.id, 'post-99');
      expect(item.profile, isNull);
    });
  });
}
