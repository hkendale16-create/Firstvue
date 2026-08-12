import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_preferences_service.dart';

class Community {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? imageUrl;
  final String? coverUrl;
  final String creatorId;
  final String privacyType;
  final String postingPermission;
  final String? rules;
  final int memberCount;
  final int followerCount;
  final bool isMember;
  final bool isFollowing;
  final bool isPending;
  final bool isCreator;
  final String? myRole;
  final DateTime createdAt;
  final List<String> tags;

  const Community({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.city,
    this.state,
    this.postalCode,
    this.imageUrl,
    this.coverUrl,
    required this.creatorId,
    this.privacyType = 'public',
    this.postingPermission = 'members',
    this.rules,
    this.memberCount = 0,
    this.followerCount = 0,
    this.isMember = false,
    this.isFollowing = false,
    this.isPending = false,
    this.isCreator = false,
    this.myRole,
    required this.createdAt,
    this.tags = const [],
  });

  bool get isPrivate => privacyType == 'private' || privacyType == 'hidden';

  bool get canPost {
    if (!isMember && !isCreator) return false;
    final role = myRole ?? (isCreator ? 'owner' : 'member');
    return switch (postingPermission) {
      'admins' => role == 'owner' || role == 'admin',
      'moderators' =>
        role == 'owner' || role == 'admin' || role == 'moderator',
      _ => true,
    };
  }

  String? get locationLabel {
    final parts =
        [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Community copyWith({
    bool? isMember,
    bool? isFollowing,
    bool? isPending,
    bool? isCreator,
    String? myRole,
    int? memberCount,
    int? followerCount,
    List<String>? tags,
  }) {
    return Community(
      id: id,
      name: name,
      description: description,
      category: category,
      city: city,
      state: state,
      postalCode: postalCode,
      imageUrl: imageUrl,
      coverUrl: coverUrl,
      creatorId: creatorId,
      privacyType: privacyType,
      postingPermission: postingPermission,
      rules: rules,
      memberCount: memberCount ?? this.memberCount,
      followerCount: followerCount ?? this.followerCount,
      isMember: isMember ?? this.isMember,
      isFollowing: isFollowing ?? this.isFollowing,
      isPending: isPending ?? this.isPending,
      isCreator: isCreator ?? this.isCreator,
      myRole: myRole ?? this.myRole,
      createdAt: createdAt,
      tags: tags ?? this.tags,
    );
  }

  factory Community.fromRow(
    Map<String, dynamic> row, {
    bool isMember = false,
    bool isFollowing = false,
    bool isPending = false,
    bool isCreator = false,
    String? myRole,
    List<String> tags = const [],
  }) {
    final createdRaw = row['created_at'];
    final creatorId = (row['creator_id'] as String?) ?? '';
    return Community(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Community',
      description: row['description'] as String?,
      category: row['category'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      postalCode: row['postal_code'] as String?,
      imageUrl: row['image_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      creatorId: creatorId,
      privacyType: (row['privacy_type'] as String?) ?? 'public',
      postingPermission: (row['posting_permission'] as String?) ?? 'members',
      rules: row['rules'] as String?,
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      isMember: isMember,
      isFollowing: isFollowing,
      isPending: isPending,
      isCreator: isCreator,
      myRole: myRole,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
      tags: tags,
    );
  }
}

class CommunityMember {
  final String userId;
  final String displayName;
  final String? username;
  final String role;
  final String status;
  final DateTime joinedAt;

  const CommunityMember({
    required this.userId,
    required this.displayName,
    this.username,
    required this.role,
    this.status = 'active',
    required this.joinedAt,
  });
}

class CommunityService {
  CommunityService._();

  static final _client = Supabase.instance.client;

  static const _communityColumns =
      'id, name, description, category, city, state, postal_code, image_url, cover_url, creator_id, privacy_type, posting_permission, rules, member_count, follower_count, created_at';

  static const _communityColumnsBase =
      'id, name, description, city, state, creator_id, member_count, created_at';

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

  static Future<Map<String, ({String role, String status})>>
      _myMembershipMap() async {
    final me = _client.auth.currentUser;
    if (me == null) return {};

    try {
      final rows = await _client
          .from('community_members')
          .select('community_id, role, status')
          .eq('profile_id', me.id);
      return {
        for (final row in rows)
          row['community_id'] as String: (
            role: (row['role'] as String?) ?? 'member',
            status: (row['status'] as String?) ?? 'active',
          ),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _myFollowIds() async {
    final me = _client.auth.currentUser;
    if (me == null) return {};

    try {
      final rows = await _client
          .from('community_follows')
          .select('community_id')
          .eq('profile_id', me.id);
      return rows.map((r) => r['community_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, List<String>>> _fetchTags(
    List<String> communityIds,
  ) async {
    if (communityIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('community_tags')
          .select('community_id, tag')
          .inFilter('community_id', communityIds);
      final map = <String, List<String>>{};
      for (final row in rows) {
        final id = row['community_id'] as String;
        final tag = (row['tag'] as String?)?.trim();
        if (tag == null || tag.isEmpty) continue;
        map.putIfAbsent(id, () => []).add(tag);
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static List<Community> _mapRows(
    List<dynamic> rows, {
    required Map<String, ({String role, String status})> memberships,
    required Set<String> followIds,
    Map<String, List<String>> tagsById = const {},
    String? currentUserId,
  }) {
    return rows.map((row) {
      final id = row['id'] as String;
      final membership = memberships[id];
      final creatorId = row['creator_id'] as String?;
      final isCreator =
          currentUserId != null && creatorId != null && creatorId == currentUserId;
      final isActiveMember = membership?.status == 'active';
      final isPending = membership?.status == 'pending';
      return Community.fromRow(
        Map<String, dynamic>.from(row as Map),
        isMember: isActiveMember || isCreator,
        isFollowing: followIds.contains(id),
        isPending: isPending,
        isCreator: isCreator,
        myRole: membership?.role ?? (isCreator ? 'owner' : null),
        tags: tagsById[id] ?? const [],
      );
    }).toList();
  }

  static Future<List<Community>> _hydrate(List<dynamic> rows) async {
    final me = _client.auth.currentUser?.id;
    final memberships = await _myMembershipMap();
    final followIds = await _myFollowIds();
    final ids = rows.map((r) => r['id'] as String).toList();
    final tags = await _fetchTags(ids);
    return _mapRows(
      rows,
      memberships: memberships,
      followIds: followIds,
      tagsById: tags,
      currentUserId: me,
    );
  }

  static Future<List<Community>> fetchCommunities({int limit = 50}) async {
    try {
      final rows = await _selectCommunities(
        (query) => query.order('created_at', ascending: false).limit(limit),
      );
      return _hydrate(rows);
    } catch (_) {
      return const [];
    }
  }

  static Future<Community?> fetchCommunityById(String id) async {
    if (id.trim().isEmpty) return null;

    try {
      final rows = await _selectCommunities(
        (query) => query.eq('id', id).limit(1),
      );
      if (rows.isEmpty) return null;
      final list = await _hydrate(rows);
      return list.isEmpty ? null : list.first;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Community>> fetchMyCommunities({int limit = 40}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final memberRows = await _client
          .from('community_members')
          .select('community_id, role, status')
          .eq('profile_id', me.id)
          .inFilter('status', ['active', 'pending'])
          .limit(limit);

      final memberIds = memberRows
          .map((r) => r['community_id'] as String)
          .toSet()
          .toList();

      final createdRows = await _selectCommunities(
        (query) => query.eq('creator_id', me.id).limit(limit),
      );
      final createdIds = createdRows.map((r) => r['id'] as String).toSet();

      final allIds = {...memberIds, ...createdIds}.toList();
      if (allIds.isEmpty) return const [];

      final rows = await _selectCommunities(
        (query) => query.inFilter('id', allIds).limit(limit),
      );
      final hydrated = await _hydrate(rows);
      hydrated.sort((a, b) {
        if (a.isCreator != b.isCreator) return a.isCreator ? -1 : 1;
        if (a.isMember != b.isMember) return a.isMember ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return hydrated;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Community>> fetchNearbyCommunities({
    int limit = 20,
    Set<String> excludeIds = const {},
  }) async {
    try {
      final prefs = await UserPreferencesService.fetch();
      var queryLimit = limit + excludeIds.length;

      List<dynamic> rows;
      if (prefs.browseEverywhere ||
          ((prefs.locationCity == null || prefs.locationCity!.isEmpty) &&
              (prefs.locationState == null || prefs.locationState!.isEmpty))) {
        rows = await _selectCommunities(
          (query) =>
              query.order('member_count', ascending: false).limit(queryLimit),
        );
      } else {
        final city = prefs.locationCity?.trim();
        final state = prefs.locationState?.trim();

        if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
          rows = await _selectCommunities(
            (query) => query
                .ilike('city', city)
                .ilike('state', state)
                .order('member_count', ascending: false)
                .limit(queryLimit),
          );
          if (rows.length < limit) {
            final more = await _selectCommunities(
              (query) => query
                  .ilike('state', state)
                  .order('member_count', ascending: false)
                  .limit(queryLimit),
            );
            final seen = rows.map((r) => r['id'] as String).toSet();
            final merged = [...rows];
            for (final row in more) {
              final id = row['id'] as String;
              if (seen.add(id)) merged.add(row);
            }
            rows = merged;
          }
        } else if (state != null && state.isNotEmpty) {
          rows = await _selectCommunities(
            (query) => query
                .ilike('state', state)
                .order('member_count', ascending: false)
                .limit(queryLimit),
          );
        } else if (city != null && city.isNotEmpty) {
          rows = await _selectCommunities(
            (query) => query
                .ilike('city', city)
                .order('member_count', ascending: false)
                .limit(queryLimit),
          );
        } else {
          rows = await _selectCommunities(
            (query) =>
                query.order('member_count', ascending: false).limit(queryLimit),
          );
        }
      }

      final hydrated = await _hydrate(rows);
      return hydrated
          .where((c) => !excludeIds.contains(c.id) && !c.isMember)
          .take(limit)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Community>> searchCommunities({
    String query = '',
    String? category,
    String filter = 'all',
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    try {
      var rows = await _selectCommunities(
        (q) {
          dynamic built = q;
          if (category != null && category.trim().isNotEmpty) {
            built = built.eq('category', category.trim());
          }
          return built.order('created_at', ascending: false).limit(limit * 2);
        },
      );

      if (trimmed.isNotEmpty) {
        final needle = trimmed.toLowerCase();
        final tagMatches = <String>{};
        try {
          final tagRows = await _client
              .from('community_tags')
              .select('community_id, tag')
              .ilike('tag', '%$trimmed%')
              .limit(40);
          for (final row in tagRows) {
            tagMatches.add(row['community_id'] as String);
          }
        } catch (_) {}

        rows = rows.where((row) {
          final id = row['id'] as String;
          if (tagMatches.contains(id)) return true;
          final name = ((row['name'] as String?) ?? '').toLowerCase();
          final city = ((row['city'] as String?) ?? '').toLowerCase();
          final state = ((row['state'] as String?) ?? '').toLowerCase();
          final cat = ((row['category'] as String?) ?? '').toLowerCase();
          final desc = ((row['description'] as String?) ?? '').toLowerCase();
          return name.contains(needle) ||
              city.contains(needle) ||
              state.contains(needle) ||
              cat.contains(needle) ||
              desc.contains(needle);
        }).toList();
      }

      var hydrated = await _hydrate(rows);

      switch (filter) {
        case 'yours':
          hydrated = hydrated.where((c) => c.isMember || c.isCreator).toList();
        case 'nearby':
          final nearby = await fetchNearbyCommunities(limit: limit);
          final nearbyIds = nearby.map((c) => c.id).toSet();
          hydrated = hydrated.where((c) => nearbyIds.contains(c.id)).toList();
          if (hydrated.isEmpty) hydrated = nearby;
        case 'new':
          hydrated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        case 'popular':
        case 'trending':
          hydrated.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        case 'recommended':
          hydrated.sort((a, b) {
            final scoreA = a.memberCount + (a.isFollowing ? 5 : 0);
            final scoreB = b.memberCount + (b.isFollowing ? 5 : 0);
            return scoreB.compareTo(scoreA);
          });
        default:
          break;
      }

      return hydrated.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<String>> fetchCategories() async {
    try {
      final rows = await _client
          .from('communities')
          .select('category')
          .not('category', 'is', null)
          .limit(100);
      final set = <String>{};
      for (final row in rows) {
        final value = (row['category'] as String?)?.trim();
        if (value != null && value.isNotEmpty) set.add(value);
      }
      final list = set.toList()..sort();
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<Community> createCommunity({
    required String name,
    String? description,
    String? city,
    String? state,
    String? category,
    String privacyType = 'public',
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to create a group.');

    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Group name is required.');

    await _ensureProfile(me);

    final insertPayload = <String, dynamic>{
      'name': trimmed,
      'description': description?.trim(),
      'city': city?.trim(),
      'state': state?.trim(),
      'creator_id': me.id,
      'member_count': 1,
      'privacy_type': privacyType,
    };
    if (category != null && category.trim().isNotEmpty) {
      insertPayload['category'] = category.trim();
    }

    Map<String, dynamic> row;
    try {
      row = await _client
          .from('communities')
          .insert(insertPayload)
          .select(_communityColumns)
          .single();
    } catch (_) {
      insertPayload.remove('category');
      insertPayload.remove('privacy_type');
      row = await _client
          .from('communities')
          .insert(insertPayload)
          .select(_communityColumnsBase)
          .single();
    }

    try {
      await _client.from('community_members').insert({
        'community_id': row['id'],
        'profile_id': me.id,
        'role': 'owner',
        'status': 'active',
      });
    } catch (_) {
      try {
        await _client.from('community_members').insert({
          'community_id': row['id'],
          'profile_id': me.id,
          'role': 'admin',
          'status': 'active',
        });
      } catch (_) {}
    }

    return Community.fromRow(
      row,
      isMember: true,
      isCreator: true,
      myRole: 'owner',
    );
  }

  /// Join a public community, or request membership for a private one.
  static Future<CommunityMembershipResult> join(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to join a group.');

    await _ensureProfile(me);

    final community = await fetchCommunityById(communityId);
    final isPrivate = community?.isPrivate ?? false;
    final status = isPrivate ? 'pending' : 'active';

    try {
      await _client.from('community_members').insert({
        'community_id': communityId,
        'profile_id': me.id,
        'role': 'member',
        'status': status,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      // Already a member/requester — update pending/active if needed.
      if (!isPrivate) {
        try {
          await _client
              .from('community_members')
              .update({'status': 'active'})
              .eq('community_id', communityId)
              .eq('profile_id', me.id);
        } catch (_) {}
      }
    }

    return CommunityMembershipResult(
      joined: !isPrivate,
      requested: isPrivate,
    );
  }

  static Future<void> leave(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to leave a group.');

    await _client
        .from('community_members')
        .delete()
        .eq('community_id', communityId)
        .eq('profile_id', me.id);
  }

  static Future<void> cancelJoinRequest(String communityId) => leave(communityId);

  static Future<void> follow(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to follow a group.');

    await _ensureProfile(me);

    try {
      await _client.from('community_follows').insert({
        'community_id': communityId,
        'profile_id': me.id,
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
        .eq('profile_id', me.id);
  }

  static Future<List<CommunityMember>> fetchMembers(
    String communityId, {
    int limit = 50,
  }) async {
    if (communityId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('community_members')
          .select(
            'profile_id, role, status, joined_at, profiles(display_name, username)',
          )
          .eq('community_id', communityId)
          .eq('status', 'active')
          .order('joined_at', ascending: true)
          .limit(limit);

      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final joinedRaw = row['joined_at'];
        return CommunityMember(
          userId: row['profile_id'] as String,
          displayName:
              (profile?['display_name'] as String?) ?? 'FirstVue member',
          username: profile?['username'] as String?,
          role: (row['role'] as String?) ?? 'member',
          status: (row['status'] as String?) ?? 'active',
          joinedAt: joinedRaw is String
              ? DateTime.tryParse(joinedRaw) ?? DateTime.now()
              : joinedRaw is DateTime
                  ? joinedRaw
                  : DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Community>> fetchHomePreview({int limit = 8}) async {
    final mine = await fetchMyCommunities(limit: limit);
    if (mine.isNotEmpty) return mine.take(limit).toList();
    return const [];
  }
}

class CommunityMembershipResult {
  final bool joined;
  final bool requested;

  const CommunityMembershipResult({
    required this.joined,
    required this.requested,
  });
}
