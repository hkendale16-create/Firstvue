import 'package:firstvue/models/publish_destination.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublishDestination', () {
    test('entity_only stays off home and vue', () {
      const dest = PublishDestination.entityOnly;
      expect(dest.appearsOnHome, isFalse);
      expect(dest.appearsOnVue, isFalse);
      expect(dest.isEntityIsolated, isTrue);
      expect(PublishDestination.parse('entity_only'), dest);
    });
  });

  group('CommunityNewsPost entity author helpers', () {
    test('uses business identity for display and navigation', () {
      final post = CommunityNewsPost(
        id: 'p1',
        body: 'Hello',
        authorId: 'user-1',
        authorName: 'FirstVue Barber',
        authorUsername: 'firstvuebarber',
        authorProfileType: 'business',
        authorProfileId: 'biz-1',
        businessId: 'biz-1',
        businessName: 'FirstVue Barber',
        createdAt: DateTime(2026, 9, 1),
        isMine: false,
        sparkCount: 0,
        sparkedByMe: false,
        savedByMe: false,
      );

      expect(post.isEntityAuthor, isTrue);
      expect(post.displayAuthorName, 'FirstVue Barber');
      expect(post.displayAuthorHandle, '@firstvuebarber');
      expect(post.entityTypeLabel, 'Business');
      expect(post.entityNavigationId, 'biz-1');
    });
  });
}
