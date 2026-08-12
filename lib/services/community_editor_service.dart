import 'package:supabase_flutter/supabase_flutter.dart';

/// Known Community Editor permission keys (must match DB / RPC checks).
class CommunityEditorPermissions {
  CommunityEditorPermissions._();

  static const approveGroupRequests = 'approve_group_requests';
  static const denyGroupRequests = 'deny_group_requests';
  static const addGroups = 'add_groups';
  static const removeGroups = 'remove_groups';
  static const moderateContent = 'moderate_content';
  static const manageNewsfeed = 'manage_newsfeed';
  static const approveGroupPosting = 'approve_group_posting';
  static const revokeGroupPosting = 'revoke_group_posting';

  static const allKeys = <String>[
    approveGroupRequests,
    denyGroupRequests,
    addGroups,
    removeGroups,
    moderateContent,
    manageNewsfeed,
    approveGroupPosting,
    revokeGroupPosting,
  ];

  /// Normalize a permissions map to known bool keys.
  static Map<String, bool> normalize(Map<String, dynamic>? raw) {
    final out = <String, bool>{
      for (final key in allKeys) key: false,
    };
    if (raw == null) return out;
    for (final key in allKeys) {
      final value = raw[key];
      if (value is bool) {
        out[key] = value;
      } else if (value is String) {
        out[key] = value.toLowerCase() == 'true';
      }
    }
    return out;
  }

  static Map<String, bool> toJsonb(Map<String, bool> permissions) {
    return {
      for (final key in allKeys) key: permissions[key] == true,
    };
  }
}

class CommunityEditor {
  final String id;
  final String communityId;
  final String userId;
  final Map<String, bool> permissions;
  final String addedBy;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? displayName;
  final String? username;
  final String? avatarUrl;

  const CommunityEditor({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.permissions,
    required this.addedBy,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
    this.username,
    this.avatarUrl,
  });

  bool get isActive => status == 'active';

  bool hasPermission(String permission) => permissions[permission] == true;

  factory CommunityEditor.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    final updatedRaw = row['updated_at'];
    final permsRaw = row['permissions'];
    Map<String, dynamic>? permsMap;
    if (permsRaw is Map<String, dynamic>) {
      permsMap = permsRaw;
    } else if (permsRaw is Map) {
      permsMap = Map<String, dynamic>.from(permsRaw);
    }

    final profile = row['profiles'];
    Map<String, dynamic>? profileMap;
    if (profile is Map<String, dynamic>) {
      profileMap = profile;
    } else if (profile is Map) {
      profileMap = Map<String, dynamic>.from(profile);
    }

    return CommunityEditor(
      id: row['id'] as String,
      communityId: row['community_id'] as String,
      userId: row['user_id'] as String,
      permissions: CommunityEditorPermissions.normalize(permsMap),
      addedBy: (row['added_by'] as String?) ?? '',
      status: (row['status'] as String?) ?? 'active',
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
      updatedAt: updatedRaw is String
          ? DateTime.tryParse(updatedRaw) ?? DateTime.now()
          : updatedRaw is DateTime
              ? updatedRaw
              : DateTime.now(),
      displayName: profileMap?['display_name'] as String?,
      username: profileMap?['username'] as String?,
      avatarUrl: profileMap?['avatar_url'] as String?,
    );
  }
}

class CommunityEditorService {
  CommunityEditorService._();

  static final _client = Supabase.instance.client;

  static const _columns =
      'id, community_id, user_id, permissions, added_by, status, '
      'created_at, updated_at';

  static const _columnsWithProfile =
      'id, community_id, user_id, permissions, added_by, status, '
      'created_at, updated_at, profiles(display_name, username, avatar_url)';

  /// Local helper: whether [editor] has [permission] while active.
  static bool hasPermission(CommunityEditor? editor, String permission) {
    if (editor == null || !editor.isActive) return false;
    return editor.hasPermission(permission);
  }

  static Future<List<CommunityEditor>> fetchEditors(
    String communityId, {
    bool activeOnly = true,
  }) async {
    if (communityId.trim().isEmpty) return const [];

    try {
      var query = _client
          .from('community_editors')
          .select(_columnsWithProfile)
          .eq('community_id', communityId);
      if (activeOnly) {
        query = query.eq('status', 'active');
      }
      final rows = await query.order('created_at', ascending: true);
      return rows.map(CommunityEditor.fromRow).toList();
    } catch (_) {
      try {
        var query = _client
            .from('community_editors')
            .select(_columns)
            .eq('community_id', communityId);
        if (activeOnly) {
          query = query.eq('status', 'active');
        }
        final rows = await query.order('created_at', ascending: true);
        return rows.map(CommunityEditor.fromRow).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<CommunityEditor> addEditor(
    String communityId,
    String userId,
    Map<String, bool> permissions,
  ) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to manage Community Editors.');
    }
    if (communityId.trim().isEmpty || userId.trim().isEmpty) {
      throw ArgumentError('communityId and userId are required.');
    }

    final payload = {
      'community_id': communityId.trim(),
      'user_id': userId.trim(),
      'permissions': CommunityEditorPermissions.toJsonb(permissions),
      'added_by': me.id,
      'status': 'active',
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final row = await _client
          .from('community_editors')
          .upsert(payload, onConflict: 'community_id,user_id')
          .select(_columnsWithProfile)
          .single();
      return CommunityEditor.fromRow(row);
    } catch (_) {
      final row = await _client
          .from('community_editors')
          .upsert(payload, onConflict: 'community_id,user_id')
          .select(_columns)
          .single();
      return CommunityEditor.fromRow(row);
    }
  }

  static Future<CommunityEditor> updatePermissions(
    String editorId,
    Map<String, bool> permissions,
  ) async {
    if (editorId.trim().isEmpty) {
      throw ArgumentError('editorId is required.');
    }

    final patch = {
      'permissions': CommunityEditorPermissions.toJsonb(permissions),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      final row = await _client
          .from('community_editors')
          .update(patch)
          .eq('id', editorId)
          .select(_columnsWithProfile)
          .single();
      return CommunityEditor.fromRow(row);
    } catch (_) {
      final row = await _client
          .from('community_editors')
          .update(patch)
          .eq('id', editorId)
          .select(_columns)
          .single();
      return CommunityEditor.fromRow(row);
    }
  }

  /// Soft-remove: set status to revoked (does not delete the row).
  static Future<void> removeEditor(String editorId) async {
    if (editorId.trim().isEmpty) return;

    await _client.from('community_editors').update({
      'status': 'revoked',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', editorId);
  }

  /// Server-side check for the current user (includes Community Leader / admin).
  static Future<bool> currentUserHasPermission(
    String communityId,
    String permission,
  ) async {
    if (communityId.trim().isEmpty || permission.trim().isEmpty) return false;
    try {
      final result = await _client.rpc(
        'community_editor_has_permission',
        params: {
          'p_community_id': communityId,
          'p_permission': permission,
        },
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
