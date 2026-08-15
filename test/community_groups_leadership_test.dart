import 'package:firstvue/services/community_hub_service.dart';
import 'package:firstvue/services/community_leader_service.dart';
import 'package:firstvue/services/community_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Community (Group) model', () {
    test('fromRow maps privacy, hub, and bio fields', () {
      final community = Community.fromRow({
        'id': 'g1',
        'name': 'Atlanta Entrepreneurs',
        'description': 'Founders and builders',
        'category': 'Business',
        'city': 'Atlanta',
        'state': 'GA',
        'postal_code': '30301',
        'image_url': 'https://example.com/g.png',
        'rules': 'Be respectful',
        'creator_id': 'p1',
        'hub_id': 'h1',
        'privacy_type': 'private',
        'posting_permission': 'members',
        'member_count': 12,
        'follower_count': 40,
        'created_at': '2026-08-01T00:00:00.000Z',
      }, isMember: true, myRole: 'owner');

      expect(community.name, 'Atlanta Entrepreneurs');
      expect(community.description, 'Founders and builders');
      expect(community.isPrivate, isTrue);
      expect(community.isPublic, isFalse);
      expect(community.hubId, 'h1');
      expect(community.myRole, 'owner');
      expect(community.canManageAs('p1'), isTrue);
      expect(community.canDeleteAs('p1'), isTrue);
      expect(community.canDeleteAs('other'), isFalse);
      expect(community.locationLabel, 'Atlanta, GA');
    });

    test('admin can manage but not delete; owner role can delete', () {
      final adminManaged = Community.fromRow({
        'id': 'g2',
        'name': 'Admin Group',
        'creator_id': 'creator',
        'privacy_type': 'public',
        'created_at': '2026-08-01T00:00:00.000Z',
      }, isMember: true, myRole: 'admin');
      expect(adminManaged.canManageAs('admin-user'), isTrue);
      expect(adminManaged.canDeleteAs('admin-user'), isFalse);
      expect(adminManaged.canDeleteAs('creator'), isTrue);

      final ownerMember = Community.fromRow({
        'id': 'g3',
        'name': 'Owner Group',
        'creator_id': 'someone-else',
        'privacy_type': 'public',
        'created_at': '2026-08-01T00:00:00.000Z',
      }, isMember: true, myRole: 'owner');
      expect(ownerMember.canDeleteAs('owner-user'), isTrue);
    });
  });

  group('CommunityHub delete permissions', () {
    test('creator and leader can delete', () {
      final hub = CommunityHub.fromRow({
        'id': 'h1',
        'name': 'Atlanta',
        'created_by_profile_id': 'creator',
        'leader_user_id': 'leader',
        'visibility': 'public',
        'status': 'active',
        'created_at': '2026-08-01T00:00:00.000Z',
      });
      expect(hub.canDeleteAs('creator'), isTrue);
      expect(hub.canDeleteAs('leader'), isTrue);
      expect(hub.canDeleteAs('member'), isFalse);
    });
  });

  group('CommunityMember roles', () {
    test('owner displays as Group Leader', () {
      final member = CommunityMember(
        userId: 'u1',
        displayName: 'Kendale',
        username: 'kendale',
        role: 'owner',
        joinedAt: DateTime(2026, 1, 1),
      );
      expect(member.isGroupLeader, isTrue);
      expect(member.roleLabel, 'Group Leader');
    });
  });

  group('CommunityHub model', () {
    test('fromRow maps umbrella community fields', () {
      final hub = CommunityHub.fromRow({
        'id': 'h1',
        'name': 'Atlanta Community',
        'description': 'Local hub for Atlanta groups',
        'category': 'City',
        'image_url': null,
        'cover_url': 'https://example.com/cover.png',
        'city': 'Atlanta',
        'state': 'GA',
        'postal_code': '30301',
        'rules': null,
        'visibility': 'public',
        'created_by_profile_id': 'p1',
        'leader_user_id': 'p1',
        'status': 'active',
        'follower_count': 3,
        'created_at': '2026-08-01T00:00:00.000Z',
      });

      expect(hub.name, 'Atlanta Community');
      expect(hub.createdByProfileId, 'p1');
      expect(hub.leaderUserId, 'p1');
      expect(hub.coverUrl, 'https://example.com/cover.png');
      expect(hub.status, 'active');
      expect(hub.locationLabel, 'Atlanta, GA');
    });

    test('fromRow does not invent leaderUserId from created_by', () {
      final hub = CommunityHub.fromRow({
        'id': 'h2',
        'name': 'Legacy Hub',
        'created_by_profile_id': 'creator-1',
        'created_at': '2026-08-01T00:00:00.000Z',
      });
      // Leadership is a separate approval; missing leader_user_id stays null.
      expect(hub.leaderUserId, isNull);
      expect(hub.createdByProfileId, 'creator-1');
      expect(hub.status, 'active');
    });
  });

  group('CommunityLeaderRequest', () {
    test('status helpers', () {
      final pending = CommunityLeaderRequest.fromRow({
        'id': 'r1',
        'profile_id': 'p1',
        'requested_city': 'Atlanta',
        'requested_state': 'GA',
        'requested_location': null,
        'reason': 'I organize local groups',
        'experience': null,
        'status': 'pending',
        'created_at': '2026-08-01T00:00:00.000Z',
      });
      expect(pending.isPending, isTrue);
      expect(pending.isApproved, isFalse);
    });
  });
}
