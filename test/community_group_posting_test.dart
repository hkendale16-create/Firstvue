import 'package:firstvue/services/community_service.dart';
import 'package:flutter_test/flutter_test.dart';

Community _group({
  String creatorId = 'owner-1',
  String postingPermission = 'members',
  bool isMember = false,
  bool isPendingMember = false,
  String? myRole,
}) {
  return Community(
    id: 'g1',
    name: 'Test Group',
    creatorId: creatorId,
    postingPermission: postingPermission,
    isMember: isMember,
    isPendingMember: isPendingMember,
    myRole: myRole,
    createdAt: DateTime.utc(2026, 8, 1),
  );
}

void main() {
  group('Community.canPostAs', () {
    test('creator can always post', () {
      final group = _group(isMember: false, myRole: null);
      expect(group.canPostAs('owner-1'), isTrue);
      expect(group.canPostAs('other'), isFalse);
    });

    test('members permission allows active members', () {
      final group = _group(isMember: true, myRole: 'member');
      expect(group.canPostAs('u2'), isTrue);
    });

    test('admins permission requires owner/admin role', () {
      final member = _group(
        postingPermission: 'admins',
        isMember: true,
        myRole: 'member',
      );
      final admin = _group(
        postingPermission: 'admins',
        isMember: true,
        myRole: 'admin',
      );
      expect(member.canPostAs('u2'), isFalse);
      expect(admin.canPostAs('u2'), isTrue);
    });

    test('pending members cannot post', () {
      final group = _group(isPendingMember: true, myRole: 'member');
      expect(group.canPostAs('u2'), isFalse);
    });
  });
}
