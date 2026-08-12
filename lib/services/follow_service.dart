import 'package:supabase_flutter/supabase_flutter.dart';

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
      try {
        await _client.from('follow_requests').insert({
          'follower_id': me.id,
          'target_id': profileId,
          'status': 'pending',
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
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
  }) async {
    if (profileId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('profile_follows')
          .select('follower_id, profiles!profile_follows_follower_id_fkey(id, display_name, username, avatar_url)')
          .eq('following_id', profileId)
          .limit(limit);

      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile != null) return FollowProfile.fromRow(profile);
        return FollowProfile(
          id: row['follower_id'] as String,
          displayName: 'FirstVue member',
        );
      }).toList();
    } catch (_) {
      return _fetchFollowersFallback(profileId, limit: limit);
    }
  }

  static Future<List<FollowProfile>> _fetchFollowersFallback(
    String profileId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _client
          .from('profile_follows')
          .select('follower_id')
          .eq('following_id', profileId)
          .limit(limit);
      final ids = rows.map((r) => r['follower_id'] as String).toList();
      return _fetchProfilesByIds(ids);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<FollowProfile>> fetchFollowing(
    String profileId, {
    int limit = 50,
  }) async {
    if (profileId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('profile_follows')
          .select('following_id, profiles!profile_follows_following_id_fkey(id, display_name, username, avatar_url)')
          .eq('follower_id', profileId)
          .limit(limit);

      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        if (profile != null) return FollowProfile.fromRow(profile);
        return FollowProfile(
          id: row['following_id'] as String,
          displayName: 'FirstVue member',
        );
      }).toList();
    } catch (_) {
      return _fetchFollowingFallback(profileId, limit: limit);
    }
  }

  static Future<List<FollowProfile>> _fetchFollowingFallback(
    String profileId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _client
          .from('profile_follows')
          .select('following_id')
          .eq('follower_id', profileId)
          .limit(limit);
      final ids = rows.map((r) => r['following_id'] as String).toList();
      return _fetchProfilesByIds(ids);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<FollowProfile>> _fetchProfilesByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', ids);
      return rows.map(FollowProfile.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }
}
