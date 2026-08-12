import 'dart:math' as math;

import 'package:firstvue/services/community_creation_service.dart';
import 'package:firstvue/services/community_editor_service.dart';
import 'package:firstvue/services/media_type_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunityCreationRequest.fromRow', () {
    test('maps fields and status helpers', () {
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
      expect(request.category, 'City');
      expect(request.requestingUserId, 'u1');
      expect(request.isPending, isTrue);
      expect(request.isApproved, isFalse);
      expect(request.isDenied, isFalse);
      expect(request.locationLabel, 'Atlanta, GA');
    });

    test('approved and denied helpers', () {
      final approved = CommunityCreationRequest.fromRow({
        'id': 'r2',
        'requesting_user_id': 'u2',
        'proposed_name': 'Approved Hub',
        'proposed_leader_user_id': 'u2',
        'status': 'approved',
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      final denied = CommunityCreationRequest.fromRow({
        'id': 'r3',
        'requesting_user_id': 'u3',
        'proposed_name': 'Denied Hub',
        'proposed_leader_user_id': 'u3',
        'status': 'denied',
        'created_at': '2026-09-01T00:00:00.000Z',
      });
      expect(approved.isApproved, isTrue);
      expect(denied.isDenied, isTrue);
    });
  });

  group('CommunityEditor permission defaults', () {
    test('normalize defaults all known keys to false', () {
      final perms = CommunityEditorPermissions.normalize(null);
      for (final key in CommunityEditorPermissions.allKeys) {
        expect(perms[key], isFalse, reason: key);
      }
    });

    test('normalize coerces string true and ignores unknown keys', () {
      final perms = CommunityEditorPermissions.normalize({
        'approve_group_requests': true,
        'add_groups': 'true',
        'unknown_key': true,
      });
      expect(perms[CommunityEditorPermissions.approveGroupRequests], isTrue);
      expect(perms[CommunityEditorPermissions.addGroups], isTrue);
      expect(perms[CommunityEditorPermissions.removeGroups], isFalse);
      expect(perms.containsKey('unknown_key'), isFalse);
    });

    test('hasPermission requires active editor', () {
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

      final revoked = CommunityEditor(
        id: editor.id,
        communityId: editor.communityId,
        userId: editor.userId,
        permissions: editor.permissions,
        addedBy: editor.addedBy,
        status: 'revoked',
        createdAt: editor.createdAt,
        updatedAt: editor.updatedAt,
      );
      expect(
        CommunityEditorService.hasPermission(
          revoked,
          CommunityEditorPermissions.manageNewsfeed,
        ),
        isFalse,
      );
      expect(
        CommunityEditorService.hasPermission(null, 'add_groups'),
        isFalse,
      );
    });
  });

  group('mediaTypeFromMetadata', () {
    test('prefers stored media type', () {
      expect(
        mediaTypeFromMetadata(
          mediaType: 'video',
          mimeType: 'image/jpeg',
          pathOrUrl: 'photo.jpg',
        ),
        'video',
      );
      expect(mediaTypeFromMetadata(mediaType: 'IMAGE'), 'image');
    });

    test('detects image vs video from mime and path', () {
      expect(mediaTypeFromMetadata(mimeType: 'image/png'), 'image');
      expect(mediaTypeFromMetadata(mimeType: 'video/mp4'), 'video');
      expect(
        mediaTypeFromMetadata(pathOrUrl: 'https://cdn.example/a/clip.mp4?x=1'),
        'video',
      );
      expect(
        mediaTypeFromMetadata(pathOrUrl: '/uploads/photo.JPEG'),
        'image',
      );
      expect(mediaTypeFromMetadata(), 'image');
    });
  });

  group('feed score conceptual', () {
    /// Mirrors SQL ranking ingredients from `fetch_ranked_main_feed`:
    /// recency decay + unseen boost + affinity + engagement − seen penalty.
    double conceptualFeedScore({
      required double ageHours,
      required int seenCount,
      double groupAffinity = 0,
      double followAffinity = 0,
      int sparkCount = 0,
      int commentCount = 0,
      double variance = 0,
      bool seenRecently = false,
    }) {
      final age = ageHours.clamp(0, 720).toDouble();
      final recency = math.exp(-age / 36.0) * 40.0;
      final unseen = switch (seenCount) {
        0 => 35.0,
        1 => 12.0,
        _ => 0.0,
      };
      final engagement =
          math.log(1 + sparkCount) * 4.0 + math.log(1 + commentCount) * 5.0;
      final lateBoost = commentCount > 0 && ageHours > 24
          ? 8.0
          : (sparkCount > 3 && ageHours > 12 ? 5.0 : 0.0);
      final penalty = seenRecently
          ? math.min(25.0, 8.0 + seenCount * 4.0)
          : (seenCount >= 3 ? math.min(18.0, seenCount * 3.0) : 0.0);
      return recency +
          unseen +
          groupAffinity * 10.0 +
          followAffinity * 14.0 +
          engagement +
          lateBoost +
          variance -
          penalty;
    }

    test('newer unseen posts outrank older heavily seen posts', () {
      final fresh = conceptualFeedScore(ageHours: 1, seenCount: 0);
      final stale = conceptualFeedScore(
        ageHours: 200,
        seenCount: 5,
        seenRecently: true,
      );
      expect(fresh, greaterThan(stale));
    });
  });
}
