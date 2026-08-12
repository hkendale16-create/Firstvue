import 'package:firstvue/models/post_identity.dart';
import 'package:firstvue/services/community_news_service.dart';
import 'package:firstvue/services/portfolio_album_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostIdentityOption', () {
    test('storage keys distinguish personal, business, and professional', () {
      const personal = PostIdentityOption.personal(displayName: 'Kendale');
      const business = PostIdentityOption(
        kind: PostIdentityKind.business,
        businessId: 'biz-1',
        label: 'FirstVue Barber Studio',
        subtitle: 'Business',
      );
      const professional = PostIdentityOption(
        kind: PostIdentityKind.professional,
        professionalProfileId: 'pro-1',
        label: 'Kendale Pro',
        subtitle: 'Professional',
      );

      expect(personal.storageKey, 'personal');
      expect(business.storageKey, 'business:biz-1');
      expect(professional.storageKey, 'professional:pro-1');
      expect(
        PostIdentityOption.matchStoredKey(
          [personal, business, professional],
          'professional:pro-1',
        )?.label,
        'Kendale Pro',
      );
    });
  });

  group('PortfolioOwnerType', () {
    test('maps to stable storage values and buckets', () {
      expect(PortfolioOwnerType.user.value, 'user');
      expect(PortfolioOwnerType.business.value, 'business');
      expect(PortfolioOwnerType.professional.value, 'professional');
      expect(
        PortfolioOwnerType.business.storageContext('b1')['business_id'],
        'b1',
      );
    });
  });

  group('CommunityNewsPost identity fields', () {
    test('copyWith keeps author metadata stable', () {
      final post = CommunityNewsPost(
        id: 'p1',
        body: 'Hello',
        authorId: 'u1',
        authorName: 'Kendale',
        businessName: null,
        communityId: 'g1',
        communityName: 'Downtown Cuts',
        communityImageUrl: 'https://example.com/g.png',
        createdAt: DateTime(2026, 8, 12),
        isMine: true,
        sparkCount: 1,
        sparkedByMe: false,
        savedByMe: false,
      );

      final updated = post.copyWith(sparkCount: 2, sparkedByMe: true);
      expect(updated.communityId, 'g1');
      expect(updated.communityName, 'Downtown Cuts');
      expect(updated.communityImageUrl, 'https://example.com/g.png');
      expect(updated.sparkCount, 2);
      expect(updated.sparkedByMe, isTrue);
    });
  });
}
