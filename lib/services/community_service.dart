import 'package:supabase_flutter/supabase_flutter.dart';

class Community {
  final String id;
  final String name;
  final String? description;
  final String? city;
  final String? state;
  final String? imageUrl;
  final String creatorId;
  final int memberCount;
  final bool isMember;
  final bool isFollowing;
  final DateTime createdAt;

  const Community({
    required this.id,
    required this.name,
    this.description,
    this.city,
    this.state,
    this.imageUrl,
    required this.creatorId,
    this.memberCount = 0,
    this.isMember = false,
    this.isFollowing = false,
    required this.createdAt,
  });

  String? get locationLabel {
    final parts = [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  factory Community.fromRow(
    Map<String, dynamic> row, {
    bool isMember = false,
    bool isFollowing = false,
  }) {
    final createdRaw = row['created_at'];
    return Community(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Group',
      description: row['description'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      imageUrl: row['image_url'] as String?,
      creatorId: (row['creator_id'] as String?) ?? '',
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      isMember: isMember,
      isFollowing: isFollowing,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CommunityMember {
  final String userId;
  final String displayName;
  final String? username;
  final String role;
  final DateTime joinedAt;

  const CommunityMember({
    required this.userId,
    required this.displayName,
    this.username,
    required this.role,
    required this.joinedAt,
  });
}

class CommunityService {
  CommunityService._();

  static final _client = Supabase.instance.client;

  static const _communityColumns =
      'id, name, description, city, state, image_url, creator_id, member_count, created_at';

  static const _communityColumnsBase =
      'id, name, description, city, state, creator_id, member_count, created_at';

  static Future<List<dynamic>> _selectCommunities(
    dynamic Function(dynamic query) configure,
  ) async {
    Future<List<dynamic>> run(String columns) async {
      dynamic query = _client.from('communities').select(columns);
      query = configure(query);
      final rows = await query;
      if (rows is List) return rows;
      return const [];
    }

    try {
      return await run(_communityColumns);
    } catch (_) {
      return await run(_communityColumnsBase);
    }
  }

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

  static Future<Set<String>> _myMembershipIds() async {
    final me = _client.auth.currentUser;
    if (me == null) return {};

    try {
      try {
        final rows = await _client
            .from('community_members')
            .select('community_id')
            .eq('profile_id', me.id);
        return rows.map((r) => r['community_id'] as String).toSet();
      } catch (_) {
        final rows = await _client
            .from('community_members')
            .select('community_id')
            .eq('user_id', me.id);
        return rows.map((r) => r['community_id'] as String).toSet();
      }
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _myFollowIds() async {
    final me = _client.auth.currentUser;
    if (me == null) return {};

    try {
      try {
        final rows = await _client
            .from('community_follows')
            .select('community_id')
            .eq('profile_id', me.id);
        return rows.map((r) => r['community_id'] as String).toSet();
      } catch (_) {
        final rows = await _client
            .from('community_follows')
            .select('community_id')
            .eq('user_id', me.id);
        return rows.map((r) => r['community_id'] as String).toSet();
      }
    } catch (_) {
      return {};
    }
  }

  static Future<List<Community>> fetchCommunities({int limit = 50}) async {
    try {
      final rows = await _client
          .from('communities')
          .select('id, name, description, city, state, creator_id, member_count, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      final memberIds = await _myMembershipIds();
      final followIds = await _myFollowIds();

      return rows
          .map(
            (row) => Community.fromRow(
              row,
              isMember: memberIds.contains(row['id'] as String),
              isFollowing: followIds.contains(row['id'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Community?> fetchCommunityById(String id) async {
    if (id.trim().isEmpty) return null;

    try {
      final row = await _client
          .from('communities')
          .select('id, name, description, city, state, creator_id, member_count, created_at')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;

      final memberIds = await _myMembershipIds();
      final followIds = await _myFollowIds();

      return Community.fromRow(
        row,
        isMember: memberIds.contains(id),
        isFollowing: followIds.contains(id),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Community> createCommunity({
    required String name,
    String? description,
    String? city,
    String? state,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to create a group.');

    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Group name is required.');

    await _ensureProfile(me);

    final row = await _client
        .from('communities')
        .insert({
          'name': trimmed,
          'description': description?.trim(),
          'city': city?.trim(),
          'state': state?.trim(),
          'creator_id': me.id,
          'member_count': 1,
        })
        .select('id, name, description, city, state, creator_id, member_count, created_at')
        .single();

    try {
      await _client.from('community_members').insert({
        'community_id': row['id'],
        'user_id': me.id,
        'role': 'admin',
      });
    } catch (_) {}

    return Community.fromRow(row, isMember: true);
  }

  static Future<void> join(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to join a group.');

    await _ensureProfile(me);

    try {
      await _client.from('community_members').insert({
        'community_id': communityId,
        'user_id': me.id,
        'role': 'member',
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  static Future<void> leave(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to leave a group.');

    await _client
        .from('community_members')
        .delete()
        .eq('community_id', communityId)
        .eq('user_id', me.id);
  }

  static Future<void> follow(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to follow a group.');

    await _ensureProfile(me);

    try {
      await _client.from('community_follows').insert({
        'community_id': communityId,
        'user_id': me.id,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  static Future<void> unfollow(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to unfollow a group.');

    await _client
        .from('community_follows')
        .delete()
        .eq('community_id', communityId)
        .eq('user_id', me.id);
  }

  static Future<List<CommunityMember>> fetchMembers(
    String communityId, {
    int limit = 50,
  }) async {
    if (communityId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('community_members')
          .select('user_id, role, joined_at, profiles(display_name, username)')
          .eq('community_id', communityId)
          .order('joined_at', ascending: true)
          .limit(limit);

      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final joinedRaw = row['joined_at'];
        return CommunityMember(
          userId: row['user_id'] as String,
          displayName:
              (profile?['display_name'] as String?) ?? 'FirstVue member',
          username: profile?['username'] as String?,
          role: (row['role'] as String?) ?? 'member',
          joinedAt: joinedRaw is String
              ? DateTime.tryParse(joinedRaw) ?? DateTime.now()
              : DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Community>> fetchYourCommunities({int limit = 20}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      List<dynamic> memberRows = const [];
      try {
        memberRows = await _client
            .from('community_members')
            .select('community_id')
            .eq('user_id', me.id)
            .limit(limit);
      } catch (_) {
        memberRows = await _client
            .from('community_members')
            .select('community_id')
            .eq('profile_id', me.id)
            .limit(limit);
      }

      final memberIds =
          memberRows.map((r) => r['community_id'] as String).toList();
      if (memberIds.isEmpty) return const [];

      final rows = await _selectCommunities(
        (query) => query.inFilter('id', memberIds).limit(limit),
      );
      final followIds = await _myFollowIds();
      return rows
          .map(
            (row) => Community.fromRow(
              row,
              isMember: true,
              isFollowing: followIds.contains(row['id'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Nearby/local discovery for Home. Prefers city/state match when available.
  static Future<List<Community>> fetchNearbyCommunities({
    int limit = 16,
  }) async {
    try {
      final user = _client.auth.currentUser;
      String? city;
      String? state;
      if (user != null) {
        try {
          final row = await _client
              .from('user_preferences')
              .select('preferred_city, preferred_state, browse_everywhere')
              .eq('profile_id', user.id)
              .maybeSingle();
          if (row != null && row['browse_everywhere'] != true) {
            city = row['preferred_city'] as String?;
            state = row['preferred_state'] as String?;
          }
        } catch (_) {}
      }

      final memberIds = (await _myMembershipIds()).toSet();
      final followIds = await _myFollowIds();

      final rows = await _selectCommunities((query) {
        dynamic q = query.order('member_count', ascending: false).limit(limit * 2);
        if ((city ?? '').trim().isNotEmpty) {
          q = q.ilike('city', city!.trim());
        } else if ((state ?? '').trim().isNotEmpty) {
          q = q.ilike('state', state!.trim());
        }
        return q;
      });

      final mapped = <Community>[];
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id == null) continue;
        // Keep nearby discovery distinct from "your groups".
        if (memberIds.contains(id)) continue;
        mapped.add(
          Community.fromRow(
            row,
            isMember: false,
            isFollowing: followIds.contains(id),
          ),
        );
        if (mapped.length >= limit) break;
      }

      if (mapped.isNotEmpty) return mapped;

      // Fallback: broad public list excluding memberships.
      final fallback = await fetchCommunities(limit: limit * 2);
      return fallback
          .where((c) => !memberIds.contains(c.id))
          .take(limit)
          .toList();
    } catch (_) {
      return fetchCommunities(limit: limit);
    }
  }

  static Future<List<Community>> fetchHomePreview({int limit = 8}) async {
    final yours = await fetchYourCommunities(limit: limit);
    if (yours.isNotEmpty) return yours;
    return fetchCommunities(limit: limit);
  }
}
