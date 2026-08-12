import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_editor_service.dart';
import 'community_service.dart';
import 'user_preferences_service.dart';

/// Parent umbrella Community (backed by `public.community_hubs`).
/// Contains many Groups (`public.communities`).
class CommunityHub {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? imageUrl;
  final String? coverUrl;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? rules;
  final String visibility;
  final String createdByProfileId;
  final String? leaderUserId;
  final String status;
  final int followerCount;
  final DateTime createdAt;

  const CommunityHub({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    this.coverUrl,
    this.city,
    this.state,
    this.postalCode,
    this.rules,
    this.visibility = 'public',
    required this.createdByProfileId,
    this.leaderUserId,
    this.status = 'active',
    this.followerCount = 0,
    required this.createdAt,
  });

  String? get locationLabel {
    final parts =
        [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  factory CommunityHub.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    return CommunityHub(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Community',
      description: row['description'] as String?,
      category: row['category'] as String?,
      imageUrl: row['image_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      postalCode: row['postal_code'] as String?,
      rules: row['rules'] as String?,
      visibility: (row['visibility'] as String?) ?? 'public',
      createdByProfileId: (row['created_by_profile_id'] as String?) ?? '',
      leaderUserId: row['leader_user_id'] as String? ??
          (row['created_by_profile_id'] as String?),
      status: (row['status'] as String?) ?? 'active',
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
    );
  }
}

class CommunityHubLeader {
  final String profileId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String role;

  const CommunityHubLeader({
    required this.profileId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    required this.role,
  });
}

/// Membership of a Group (`communities`) under an umbrella Community hub.
class CommunityGroupMembership {
  final String id;
  final String communityId;
  final String groupId;
  final String status;
  final bool canPostToCommunityFeed;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final Community? group;

  const CommunityGroupMembership({
    required this.id,
    required this.communityId,
    required this.groupId,
    required this.status,
    this.canPostToCommunityFeed = false,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    this.group,
  });

  bool get isPending => status == 'pending';
  bool get isApproved =>
      status == 'approved' || status == 'approved_for_feed';
  bool get isApprovedForFeed => status == 'approved_for_feed';

  factory CommunityGroupMembership.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    final approvedRaw = row['approved_at'];
    Community? group;
    final nested = row['communities'];
    if (nested is Map<String, dynamic>) {
      group = Community.fromRow(nested);
    } else if (nested is Map) {
      group = Community.fromRow(Map<String, dynamic>.from(nested));
    }

    return CommunityGroupMembership(
      id: row['id'] as String,
      communityId: row['community_id'] as String,
      groupId: row['group_id'] as String,
      status: (row['status'] as String?) ?? 'pending',
      canPostToCommunityFeed:
          row['can_post_to_community_feed'] as bool? ?? false,
      approvedBy: row['approved_by'] as String?,
      approvedAt: approvedRaw is String
          ? DateTime.tryParse(approvedRaw)
          : approvedRaw is DateTime
              ? approvedRaw
              : null,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
      group: group,
    );
  }
}

/// Soft-removable reference from a hub feed to a Group news post.
class CommunityFeedPostRef {
  final String id;
  final String communityId;
  final String groupId;
  final String sourcePostId;
  final String? sharedBy;
  final DateTime createdAt;
  final DateTime? removedFromCommunityAt;

  const CommunityFeedPostRef({
    required this.id,
    required this.communityId,
    required this.groupId,
    required this.sourcePostId,
    this.sharedBy,
    required this.createdAt,
    this.removedFromCommunityAt,
  });

  factory CommunityFeedPostRef.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    final removedRaw = row['removed_from_community_at'];
    return CommunityFeedPostRef(
      id: row['id'] as String,
      communityId: row['community_id'] as String,
      groupId: row['group_id'] as String,
      sourcePostId: row['source_post_id'] as String,
      sharedBy: row['shared_by'] as String?,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
      removedFromCommunityAt: removedRaw is String
          ? DateTime.tryParse(removedRaw)
          : removedRaw is DateTime
              ? removedRaw
              : null,
    );
  }
}

class CommunityHubService {
  CommunityHubService._();

  static final _client = Supabase.instance.client;

  static const _columns =
      'id, name, description, category, image_url, cover_url, city, state, '
      'postal_code, rules, visibility, created_by_profile_id, leader_user_id, '
      'status, follower_count, created_at';

  static const _columnsLegacy =
      'id, name, description, category, image_url, city, state, postal_code, '
      'rules, visibility, created_by_profile_id, follower_count, created_at';

  static const _groupMembershipColumns =
      'id, community_id, group_id, status, can_post_to_community_feed, '
      'approved_by, approved_at, created_at';

  static const _groupMembershipWithGroup =
      'id, community_id, group_id, status, can_post_to_community_feed, '
      'approved_by, approved_at, created_at, '
      'communities(id, name, description, category, city, state, postal_code, '
      'image_url, rules, creator_id, hub_id, privacy_type, posting_permission, '
      'member_count, follower_count, created_at)';

  static const _feedPostColumns =
      'id, community_id, group_id, source_post_id, shared_by, created_at, '
      'removed_from_community_at';

  static Future<List<Map<String, dynamic>>> _selectHubRows({
    required dynamic Function(dynamic query) configure,
  }) async {
    Future<List<Map<String, dynamic>>> run(String columns) async {
      dynamic query = _client.from('community_hubs').select(columns);
      query = configure(query);
      final rows = await query;
      return List<Map<String, dynamic>>.from(rows as List);
    }

    try {
      return await run(_columns);
    } catch (_) {
      return await run(_columnsLegacy);
    }
  }

  static Future<List<CommunityHub>> fetchHubs({int limit = 40}) async {
    try {
      final rows = await _selectHubRows(
        configure: (query) =>
            query.order('created_at', ascending: false).limit(limit),
      );
      return rows.map(CommunityHub.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<CommunityHub?> fetchHubById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final rows = await _selectHubRows(
        configure: (query) => query.eq('id', id).limit(1),
      );
      if (rows.isEmpty) return null;
      return CommunityHub.fromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  static Future<List<CommunityHub>> fetchNearbyHubs({int limit = 16}) async {
    try {
      final prefs = await UserPreferencesService.fetch();
      final city = prefs.locationCity?.trim();
      final state = prefs.locationState?.trim();

      final rows = await _selectHubRows(
        configure: (query) {
          var q = query;
          if (city != null &&
              city.isNotEmpty &&
              state != null &&
              state.isNotEmpty) {
            q = q.or('city.ilike.%$city%,state.ilike.%$state%');
          } else if (city != null && city.isNotEmpty) {
            q = q.ilike('city', '%$city%');
          } else if (state != null && state.isNotEmpty) {
            q = q.ilike('state', '%$state%');
          }
          return q.order('created_at', ascending: false).limit(limit);
        },
      );
      return rows.map(CommunityHub.fromRow).toList();
    } catch (_) {
      return fetchHubs(limit: limit);
    }
  }

  static Future<CommunityHub> createHub({
    required String name,
    String? description,
    String? category,
    String? city,
    String? state,
    String? postalCode,
    String? rules,
    String visibility = 'public',
    XFile? imageFile,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to create a community.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Community name is required.');
    }

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await CommunityMediaService.uploadHubImage(
        hubIdHint: me.id,
        file: imageFile,
      );
    }

    Map<String, dynamic> row;
    try {
      row = await _client
          .from('community_hubs')
          .insert({
            'name': trimmed,
            'description': description?.trim(),
            'category': category?.trim(),
            'city': city?.trim(),
            'state': state?.trim(),
            'postal_code': postalCode?.trim(),
            'rules': rules?.trim(),
            'visibility': visibility == 'private' ? 'private' : 'public',
            'image_url': imageUrl,
            'created_by_profile_id': me.id,
            'leader_user_id': me.id,
            'status': 'active',
          })
          .select(_columns)
          .single();
    } catch (_) {
      row = await _client
          .from('community_hubs')
          .insert({
            'name': trimmed,
            'description': description?.trim(),
            'category': category?.trim(),
            'city': city?.trim(),
            'state': state?.trim(),
            'postal_code': postalCode?.trim(),
            'rules': rules?.trim(),
            'visibility': visibility == 'private' ? 'private' : 'public',
            'image_url': imageUrl,
            'created_by_profile_id': me.id,
          })
          .select(_columnsLegacy)
          .single();
    }

    try {
      await _client.from('community_hub_roles').insert({
        'hub_id': row['id'],
        'profile_id': me.id,
        'role': 'creator',
        'status': 'active',
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }

    return CommunityHub.fromRow(row);
  }

  static Future<CommunityHub> updateHub({
    required String hubId,
    String? name,
    String? description,
    String? category,
    String? city,
    String? state,
    String? postalCode,
    String? rules,
    String? visibility,
    String? coverUrl,
    String? status,
    bool clearImage = false,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) patch['name'] = name.trim();
    if (description != null) patch['description'] = description.trim();
    if (category != null) patch['category'] = category.trim();
    if (city != null) patch['city'] = city.trim();
    if (state != null) patch['state'] = state.trim();
    if (postalCode != null) patch['postal_code'] = postalCode.trim();
    if (rules != null) patch['rules'] = rules.trim();
    if (visibility != null) {
      patch['visibility'] = visibility == 'private' ? 'private' : 'public';
    }
    if (coverUrl != null) patch['cover_url'] = coverUrl.trim();
    if (status != null) patch['status'] = status.trim();
    if (clearImage) patch['image_url'] = null;

    try {
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columns)
          .single();
      return CommunityHub.fromRow(row);
    } catch (_) {
      patch.remove('cover_url');
      patch.remove('status');
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columnsLegacy)
          .single();
      return CommunityHub.fromRow(row);
    }
  }

  static Future<CommunityHub> updateHubImage({
    required String hubId,
    required XFile file,
  }) async {
    final imageUrl = await CommunityMediaService.uploadHubImage(
      hubIdHint: hubId,
      file: file,
    );
    try {
      final row = await _client
          .from('community_hubs')
          .update({
            'image_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hubId)
          .select(_columns)
          .single();
      return CommunityHub.fromRow(row);
    } catch (_) {
      final row = await _client
          .from('community_hubs')
          .update({
            'image_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', hubId)
          .select(_columnsLegacy)
          .single();
      return CommunityHub.fromRow(row);
    }
  }

  static Future<CommunityHubLeader?> fetchPrimaryLeader(String hubId) async {
    try {
      final hub = await fetchHubById(hubId);
      if (hub?.leaderUserId != null && hub!.leaderUserId!.isNotEmpty) {
        final profile = await _client
            .from('profiles')
            .select('display_name, username, avatar_url')
            .eq('id', hub.leaderUserId!)
            .maybeSingle();
        return CommunityHubLeader(
          profileId: hub.leaderUserId!,
          displayName:
              (profile?['display_name'] as String?) ?? 'FirstVue member',
          username: profile?['username'] as String?,
          avatarUrl: profile?['avatar_url'] as String?,
          role: 'creator',
        );
      }

      final roleRows = await _client
          .from('community_hub_roles')
          .select('profile_id, role')
          .eq('hub_id', hubId)
          .eq('status', 'active')
          .order('created_at', ascending: true)
          .limit(10);

      Map<String, dynamic>? chosen;
      for (final preferred in ['creator', 'lead_leader', 'leader']) {
        for (final row in roleRows) {
          if (row['role'] == preferred) {
            chosen = row;
            break;
          }
        }
        if (chosen != null) break;
      }
      chosen ??= roleRows.isNotEmpty ? roleRows.first : null;
      if (chosen == null) {
        if (hub == null || hub.createdByProfileId.isEmpty) return null;
        chosen = {
          'profile_id': hub.createdByProfileId,
          'role': 'creator',
        };
      }

      final profileId = chosen['profile_id'] as String;
      final profile = await _client
          .from('profiles')
          .select('display_name, username, avatar_url')
          .eq('id', profileId)
          .maybeSingle();

      return CommunityHubLeader(
        profileId: profileId,
        displayName:
            (profile?['display_name'] as String?) ?? 'FirstVue member',
        username: profile?['username'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
        role: (chosen['role'] as String?) ?? 'leader',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<CommunityEditor>> fetchEditors(String hubId) {
    return CommunityEditorService.fetchEditors(hubId);
  }

  static Future<List<CommunityGroupMembership>> fetchCommunityGroups(
    String hubId, {
    bool includePending = true,
  }) async {
    if (hubId.trim().isEmpty) return const [];

    try {
      var query = _client
          .from('community_groups')
          .select(_groupMembershipWithGroup)
          .eq('community_id', hubId)
          .neq('status', 'removed');
      if (!includePending) {
        query = query.inFilter('status', ['approved', 'approved_for_feed']);
      }
      final rows = await query.order('created_at', ascending: false);
      return rows.map(CommunityGroupMembership.fromRow).toList();
    } catch (_) {
      try {
        var query = _client
            .from('community_groups')
            .select(_groupMembershipColumns)
            .eq('community_id', hubId)
            .neq('status', 'removed');
        if (!includePending) {
          query = query.inFilter('status', ['approved', 'approved_for_feed']);
        }
        final rows = await query.order('created_at', ascending: false);
        return rows.map(CommunityGroupMembership.fromRow).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  /// Leader/editor directly adds an already-approved Group to the Community.
  static Future<CommunityGroupMembership> addGroupToCommunity({
    required String hubId,
    required String groupId,
    bool canPostToCommunityFeed = false,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to manage Community Groups.');
    }

    final status =
        canPostToCommunityFeed ? 'approved_for_feed' : 'approved';
    final row = await _client
        .from('community_groups')
        .upsert(
          {
            'community_id': hubId,
            'group_id': groupId,
            'status': status,
            'can_post_to_community_feed': canPostToCommunityFeed,
            'approved_by': me.id,
            'approved_at': DateTime.now().toIso8601String(),
            'removed_at': null,
          },
          onConflict: 'community_id,group_id',
        )
        .select(_groupMembershipWithGroup)
        .single();
    return CommunityGroupMembership.fromRow(row);
  }

  /// Group leader/admin requests to join this Community (pending review).
  static Future<CommunityGroupMembership> requestGroupJoin({
    required String hubId,
    required String groupId,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to request Community membership.');
    }

    final row = await _client
        .from('community_groups')
        .upsert(
          {
            'community_id': hubId,
            'group_id': groupId,
            'status': 'pending',
            'can_post_to_community_feed': false,
            'removed_at': null,
          },
          onConflict: 'community_id,group_id',
        )
        .select(_groupMembershipWithGroup)
        .single();
    return CommunityGroupMembership.fromRow(row);
  }

  static Future<void> reviewGroupMembership({
    required String hubId,
    required String groupId,
    required bool approve,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to review Group membership.');
    }

    final patch = <String, dynamic>{
      'status': approve ? 'approved' : 'denied',
      'can_post_to_community_feed': false,
    };
    if (approve) {
      patch['approved_by'] = me.id;
      patch['approved_at'] = DateTime.now().toIso8601String();
      patch['removed_at'] = null;
    }

    await _client
        .from('community_groups')
        .update(patch)
        .eq('community_id', hubId)
        .eq('group_id', groupId);
  }

  static Future<void> setGroupFeedPosting({
    required String hubId,
    required String groupId,
    required bool allow,
  }) async {
    await _client.rpc(
      'set_group_community_feed_posting',
      params: {
        'p_community_id': hubId,
        'p_group_id': groupId,
        'p_allow': allow,
      },
    );
  }

  static Future<void> removeGroupFromCommunity({
    required String hubId,
    required String groupId,
  }) async {
    await _client.from('community_groups').update({
      'status': 'removed',
      'can_post_to_community_feed': false,
      'removed_at': DateTime.now().toIso8601String(),
    }).eq('community_id', hubId).eq('group_id', groupId);
  }

  /// Feed refs for a Community hub (not soft-removed).
  static Future<List<CommunityFeedPostRef>> fetchCommunityFeedPosts(
    String hubId, {
    int limit = 40,
  }) async {
    if (hubId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('community_feed_posts')
          .select(_feedPostColumns)
          .eq('community_id', hubId)
          .isFilter('removed_from_community_at', null)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(CommunityFeedPostRef.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Soft-remove a post from the Community feed (source Group post remains).
  static Future<void> softRemoveFeedPost(String feedPostId) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to moderate the Community feed.');
    }
    if (feedPostId.trim().isEmpty) return;

    await _client.from('community_feed_posts').update({
      'removed_from_community_at': DateTime.now().toIso8601String(),
      'removed_by': me.id,
    }).eq('id', feedPostId);
  }

  static Future<List<Map<String, dynamic>>> fetchPendingLinkRequests(
    String hubId,
  ) async {
    try {
      final rows = await _client
          .from('community_group_link_requests')
          .select(
            'id, community_id, requested_by_profile_id, status, created_at, '
            'communities(name, image_url)',
          )
          .eq('hub_id', hubId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> reviewLinkRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _client.rpc(
      'review_community_group_link_request',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
      },
    );
  }
}
