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
      expect(community.locationLabel, 'Atlanta, GA');
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

    test('fromRow falls back leaderUserId to created_by when missing', () {
      final hub = CommunityHub.fromRow({
        'id': 'h2',
        'name': 'Legacy Hub',
        'created_by_profile_id': 'creator-1',
        'created_at': '2026-08-01T00:00:00.000Z',
      });
      expect(hub.leaderUserId, 'creator-1');
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
