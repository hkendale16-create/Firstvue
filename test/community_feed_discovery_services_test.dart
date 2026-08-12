import 'package:firstvue/services/community_creation_service.dart';
import 'package:firstvue/services/community_editor_service.dart';
import 'package:firstvue/services/community_hub_service.dart';
import 'package:firstvue/services/post_impressions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityCreationRequest', () {
    test('fromRow maps table fields and status helpers', () {
      final request = CommunityCreationRequest.fromRow({
        'id': 'r1',
        'requesting_user_id': 'u1',
        'proposed_name': 'Atlanta Community',
        'description': 'City hub',
        'category': 'City',
        'city': 'Atlanta',
        'state': 'GA',
        'postal_code': '30301',
        'location_label': 'Atlanta, GA',
        'proposed_leader_user_id': 'u1',
        'reason': 'I lead local groups',
        'status': 'pending',
        'reviewed_by': null,
        'reviewed_at': null,
        'denial_reason': null,
        'created_community_id': null,
        'created_at': '2026-09-01T00:00:00.000Z',
      });

      expect(request.proposedName, 'Atlanta Community');
      expect(request.isPending, isTrue);
      expect(request.isApproved, isFalse);
      expect(request.locationLabel, 'Atlanta, GA');
    });
  });

  group('CommunityEditorPermissions', () {
    test('normalize fills known keys and coerces values', () {
      final perms = CommunityEditorPermissions.normalize({
        'approve_group_requests': true,
        'add_groups': 'true',
        'unknown_key': true,
      });

      expect(perms['approve_group_requests'], isTrue);
      expect(perms['add_groups'], isTrue);
      expect(perms['remove_groups'], isFalse);
      expect(perms.containsKey('unknown_key'), isFalse);
    });

    test('hasPermission helper requires active editor', () {
      final editor = CommunityEditor(
        id: 'e1',
        communityId: 'c1',
        userId: 'u1',
        permissions: CommunityEditorPermissions.normalize({
          'manage_newsfeed': true,
        }),
        addedBy: 'leader',
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      expect(
        CommunityEditorService.hasPermission(
          editor,
          CommunityEditorPermissions.manageNewsfeed,
        ),
        isTrue,
      );
      expect(
        CommunityEditorService.hasPermission(
          editor.copyWithStatus('revoked'),
          CommunityEditorPermissions.manageNewsfeed,
        ),
        isFalse,
      );
      expect(CommunityEditorService.hasPermission(null, 'add_groups'), isFalse);
    });
  });

  group('CommunityGroupMembership', () {
    test('fromRow maps nested group', () {
      final membership = CommunityGroupMembership.fromRow({
        'id': 'm1',
        'community_id': 'hub1',
        'group_id': 'g1',
        'status': 'approved_for_feed',
        'can_post_to_community_feed': true,
        'approved_by': 'u1',
        'approved_at': '2026-09-01T00:00:00.000Z',
        'created_at': '2026-09-01T00:00:00.000Z',
        'communities': {
          'id': 'g1',
          'name': 'Founders',
          'creator_id': 'u2',
          'created_at': '2026-08-01T00:00:00.000Z',
        },
      });

      expect(membership.isApproved, isTrue);
      expect(membership.isApprovedForFeed, isTrue);
      expect(membership.canPostToCommunityFeed, isTrue);
      expect(membership.group?.name, 'Founders');
    });
  });

  group('PostImpressionsService debounce key', () {
    test('clearDebounceCache is callable', () {
      PostImpressionsService.clearDebounceCache();
      expect(PostImpressionsService.debounceWindow.inSeconds, greaterThan(0));
    });
  });
}

extension on CommunityEditor {
  CommunityEditor copyWithStatus(String status) {
    return CommunityEditor(
      id: id,
      communityId: communityId,
      userId: userId,
      permissions: permissions,
      addedBy: addedBy,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl,
    );
  }
}
