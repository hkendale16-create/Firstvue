import 'package:firstvue/services/community_discovery_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityDiscoverySearchService.shouldSearch', () {
    test('requires at least 2 characters', () {
      expect(CommunityDiscoverySearchService.shouldSearch(''), isFalse);
      expect(CommunityDiscoverySearchService.shouldSearch('a'), isFalse);
      expect(CommunityDiscoverySearchService.shouldSearch('  a  '), isFalse);
      expect(CommunityDiscoverySearchService.shouldSearch('at'), isTrue);
      expect(CommunityDiscoverySearchService.shouldSearch('Atlanta'), isTrue);
    });

    test('supports @handle queries with 2+ chars after @', () {
      expect(CommunityDiscoverySearchService.shouldSearch('@'), isFalse);
      expect(CommunityDiscoverySearchService.shouldSearch('@a'), isFalse);
      expect(CommunityDiscoverySearchService.shouldSearch('@at'), isTrue);
    });
  });

  group('CommunityDiscoverySearchService.sanitizeForIlike', () {
    test('strips filter-breaking characters', () {
      expect(
        CommunityDiscoverySearchService.sanitizeForIlike('food%_truck,(night)'),
        'food truck night',
      );
    });

    test('collapses whitespace', () {
      expect(
        CommunityDiscoverySearchService.sanitizeForIlike('  atlanta   food  '),
        'atlanta food',
      );
    });
  });

  group('CommunityDiscoveryHit', () {
    test('labels Group vs Community and formats counts', () {
      const group = CommunityDiscoveryHit(
        id: 'g1',
        kind: CommunityDiscoveryKind.group,
        name: 'Atlanta Foodies',
        category: 'Food & Dining',
        memberCount: 12000,
      );
      const hub = CommunityDiscoveryHit(
        id: 'h1',
        kind: CommunityDiscoveryKind.community,
        name: 'Atlanta Nightlife',
        category: 'Entertainment',
        followerCount: 3400,
      );

      expect(group.kindLabel, 'Group');
      expect(hub.kindLabel, 'Community');
      expect(group.countLabel, '12K members');
      expect(hub.countLabel, '3.4K members');
      expect(group.subtitle, contains('Group'));
      expect(group.subtitle, contains('Food & Dining'));
      expect(hub.primaryActionLabel, 'Follow');
      expect(group.primaryActionLabel, 'Join');
    });

    test('private group action is Request; pending/joined states', () {
      const pending = CommunityDiscoveryHit(
        id: 'g2',
        kind: CommunityDiscoveryKind.group,
        name: 'Private Club',
        isPrivate: true,
        isPendingMember: true,
      );
      const joined = CommunityDiscoveryHit(
        id: 'g3',
        kind: CommunityDiscoveryKind.group,
        name: 'Joined Club',
        isMember: true,
      );
      const requestable = CommunityDiscoveryHit(
        id: 'g4',
        kind: CommunityDiscoveryKind.group,
        name: 'Invite Only',
        isPrivate: true,
      );

      expect(pending.primaryActionLabel, 'Pending');
      expect(pending.canJoinOrFollow, isFalse);
      expect(joined.primaryActionLabel, 'Joined');
      expect(requestable.primaryActionLabel, 'Request');
      expect(requestable.canJoinOrFollow, isTrue);
    });
  });

  group('CommunityDiscoverySearchService.popularSlice', () {
    test('ranks by count and limits without extra data', () {
      final items = [
        (name: 'a', count: 2),
        (name: 'b', count: 9),
        (name: 'c', count: 0),
        (name: 'd', count: 5),
      ];
      final popular = CommunityDiscoverySearchService.popularSlice(
        items,
        countOf: (e) => e.count,
        limit: 2,
      );
      expect(popular.map((e) => e.name), ['b', 'd']);
    });

    test('falls back to full ranking when all counts are zero', () {
      final items = [
        (name: 'a', count: 0),
        (name: 'b', count: 0),
      ];
      final popular = CommunityDiscoverySearchService.popularSlice(
        items,
        countOf: (e) => e.count,
        limit: 2,
      );
      expect(popular.length, 2);
    });
  });
}
