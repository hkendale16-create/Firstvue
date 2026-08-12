import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';

class FollowProfile {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  const FollowProfile({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  factory FollowProfile.fromRow(Map<String, dynamic> row) {
    return FollowProfile(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? 'FirstVue member',
      username: row['username'] as String?,
      avatarUrl: row['avatar_url'] as String?,
    );
  }
}

enum FollowStatus { notFollowing, following, pending }

class FollowRequestItem {
  final String id;
  final String requesterId;
  final String displayName;
  final String? username;
  final DateTime createdAt;

  const FollowRequestItem({
    required this.id,
    required this.requesterId,
    required this.displayName,
    this.username,
    required this.createdAt,
  });
}

class FollowService {
  FollowService._();

  static final _client = Supabase.instance.client;

  static Future<void> _ensureProfile(User user) async {
    final displayName = user.email?.split('@').first;
    try {
      await _client.rpc(
        'ensure_user_profile',
        params: {'display_name': displayName},
      );
    } catch (_) {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        await _client.from('profiles').insert({
          'id': user.id,
          'display_name': displayName,
        });
      }
    }
  }

  static Future<bool> _isPrivateProfile(String profileId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('is_private')
          .eq('id', profileId)
          .maybeSingle();
      return row?['is_private'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<FollowStatus> followStatus(String profileId) async {
    final me = _client.auth.currentUser;
    if (me == null || me.id == profileId) return FollowStatus.notFollowing;

    if (await isFollowing(profileId)) return FollowStatus.following;

    try {
      final pending = await _client
          .from('follow_requests')
          .select('id')
          .eq('follower_id', me.id)
          .eq('target_id', profileId)
          .eq('status', 'pending')
          .maybeSingle();
      if (pending != null) return FollowStatus.pending;
    } catch (_) {}

    return FollowStatus.notFollowing;
  }

  static Future<String> _actorLabel(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('display_name, username')
          .eq('id', userId)
          .maybeSingle();
      final username = row?['username'] as String?;
      if (username != null && username.trim().isNotEmpty) {
        return '@${username.trim()}';
      }
      return (row?['display_name'] as String?) ?? 'Someone';
    } catch (_) {
      return 'Someone';
    }
  }

  static Future<void> follow(String profileId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to follow profiles.');
    if (me.id == profileId) {
      throw ArgumentError('You cannot follow yourself.');
    }

    await _ensureProfile(me);

    if (await isFollowing(profileId)) return;

    final isPrivate = await _isPrivateProfile(profileId);

    if (isPrivate) {
      String? requestId;
      try {
        final inserted = await _client
            .from('follow_requests')
            .insert({
              'follower_id': me.id,
              'target_id': profileId,
              'status': 'pending',
            })
            .select('id')
            .maybeSingle();
        requestId = inserted?['id'] as String?;
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        requestId = await findPendingRequestId(me.id, profileId);
      }
      final actor = await _actorLabel(me.id);
      await ActivityNotificationsService.notifyUser(
        userId: profileId,
        type: 'follow_request',
        title: '$actor requested to follow you',
        payload: {
          'profile_id': me.id,
          'request_id': ?requestId,
        },
      );
      return;
    }

    try {
      await _client.from('profile_follows').insert({
        'follower_id': me.id,
        'following_id': profileId,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }

    final actor = await _actorLabel(me.id);
    await ActivityNotificationsService.notifyUser(
      userId: profileId,
      type: 'follow',
      title: '$actor started following you',
      payload: {'profile_id': me.id},
    );
  }

  static Future<void> unfollow(String profileId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to unfollow profiles.');

    await _client
        .from('profile_follows')
        .delete()
        .eq('follower_id', me.id)
        .eq('following_id', profileId);

    try {
      await _client
          .from('follow_requests')
          .delete()
          .eq('follower_id', me.id)
          .eq('target_id', profileId);
    } catch (_) {}
  }

  static Future<bool> isFollowing(String profileId) async {
    final me = _client.auth.currentUser;
    if (me == null || me.id == profileId) return false;

    try {
      final row = await _client
          .from('profile_follows')
          .select('follower_id')
          .eq('follower_id', me.id)
          .eq('following_id', profileId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<int> fetchFollowerCount(String profileId) async {
    if (profileId.trim().isEmpty) return 0;
    try {
      final rows = await _client
          .from('profile_follows')
          .select('follower_id')
          .eq('following_id', profileId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> fetchFollowingCount(String profileId) async {
    if (profileId.trim().isEmpty) return 0;
    try {
      final rows = await _client
          .from('profile_follows')
          .select('following_id')
          .eq('follower_id', profileId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<FollowProfile>> fetchFollowers(
    String profileId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (profileId.trim().isEmpty) return const [];

    final rpc = await _fetchFollowListRpc(
      functionName: 'list_profile_followers',
      profileId: profileId,
      limit: limit,
      offset: offset,
    );
    if (rpc != null) return rpc;

    return _fetchFollowProfiles(
      profileId: profileId,
      column: 'follower_id',
      filterColumn: 'following_id',
      limit: limit,
      offset: offset,
    );
  }

  static Future<List<FollowProfile>> fetchFollowing(
    String profileId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (profileId.trim().isEmpty) return const [];

    final rpc = await _fetchFollowListRpc(
      functionName: 'list_profile_following',
      profileId: profileId,
      limit: limit,
      offset: offset,
    );
    if (rpc != null) return rpc;

    return _fetchFollowProfiles(
      profileId: profileId,
      column: 'following_id',
      filterColumn: 'follower_id',
      limit: limit,
      offset: offset,
    );
  }

  static Future<List<FollowProfile>?> _fetchFollowListRpc({
    required String functionName,
    required String profileId,
    required int limit,
    required int offset,
  }) async {
    try {
      final rows = await _client.rpc(
        functionName,
        params: {
          'p_profile_id': profileId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      if (rows is! List) return const [];
      return rows
          .map((row) => FollowProfile.fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<List<FollowProfile>> _fetchFollowProfiles({
    required String profileId,
    required String column,
    required String filterColumn,
    required int limit,
    required int offset,
  }) async {
    try {
      final rows = await _fetchFollowRows(
        filterColumn: filterColumn,
        profileId: profileId,
        column: column,
        limit: limit,
        offset: offset,
      );
      final ids = rows.map((row) => row[column] as String).toList();
      return _fetchProfilesByIds(ids);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchFollowRows({
    required String filterColumn,
    required String profileId,
    required String column,
    required int limit,
    required int offset,
  }) async {
    try {
      final rows = await _client
          .from('profile_follows')
          .select(column)
          .eq(filterColumn, profileId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      final rows = await _client
          .from('profile_follows')
          .select(column)
          .eq(filterColumn, profileId)
          .range(offset, offset + limit - 1);
      return rows.cast<Map<String, dynamic>>();
    }
  }

  static Future<List<FollowProfile>> _fetchProfilesByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];

    List<dynamic> rows;
    try {
      rows = await _client
          .from('profiles')
          .select('id, display_name, username')
          .inFilter('id', ids);
    } catch (_) {
      try {
        rows = await _client
            .from('profiles')
            .select('id, display_name')
            .inFilter('id', ids);
      } catch (_) {
        return ids
            .map((id) => FollowProfile(id: id, displayName: 'FirstVue member'))
            .toList();
      }
    }

    final byId = {
      for (final row in rows)
        row['id'] as String: FollowProfile.fromRow(row as Map<String, dynamic>),
    };
    return ids
        .map(
          (id) => byId[id] ?? FollowProfile(id: id, displayName: 'FirstVue member'),
        )
        .toList();
  }

  static Future<List<FollowRequestItem>> fetchPendingIncoming() async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final rows = await _client
          .from('follow_requests')
          .select('id, requester_id, created_at')
          .eq('target_id', me.id)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(30);

      if (rows.isEmpty) return const [];

      final requesterIds =
          rows.map((row) => row['requester_id'] as String).toList();
      final profiles = await _fetchProfilesByIds(requesterIds);
      final profileById = {for (final p in profiles) p.id: p};

      return rows.map((row) {
        final requesterId = row['requester_id'] as String;
        final profile = profileById[requesterId];
        final createdRaw = row['created_at'];
        return FollowRequestItem(
          id: row['id'] as String,
          requesterId: requesterId,
          displayName: profile?.displayName ?? 'FirstVue member',
          username: profile?.username,
          createdAt: createdRaw is String
              ? DateTime.tryParse(createdRaw) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> acceptRequest(String requestId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to manage requests.');

    final request = await _client
        .from('follow_requests')
        .select('id, requester_id, target_id, status')
        .eq('id', requestId)
        .eq('target_id', me.id)
        .eq('status', 'pending')
        .maybeSingle();

    if (request == null) return;

    final requesterId = request['requester_id'] as String;

    await _client.from('follow_requests').update({
      'status': 'accepted',
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);

    try {
      await _client.from('profile_follows').insert({
        'follower_id': requesterId,
        'following_id': me.id,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }

    final accepter = await _actorLabel(me.id);
    await ActivityNotificationsService.notifyUser(
      userId: requesterId,
      type: 'follow_accepted',
      title: '$accepter accepted your follow request',
      payload: {'profile_id': me.id},
    );
  }

  static Future<String?> findPendingRequestId(
    String requesterId,
    String targetId,
  ) async {
    try {
      final row = await _client
          .from('follow_requests')
          .select('id')
          .eq('follower_id', requesterId)
          .eq('target_id', targetId)
          .eq('status', 'pending')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> resolveRequestId({
    required String requesterId,
    String? requestId,
  }) async {
    if (requestId != null && requestId.isNotEmpty) return requestId;
    final me = _client.auth.currentUser;
    if (me == null) return null;
    return findPendingRequestId(requesterId, me.id);
  }

  static Future<void> declineRequest(String requestId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to manage requests.');

    await _client
        .from('follow_requests')
        .update({
          'status': 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('target_id', me.id)
        .eq('status', 'pending');
  }
}
