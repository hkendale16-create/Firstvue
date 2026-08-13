import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'entity_image_url.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';
import 'user_preferences_service.dart';

/// A FirstVue Group (backed by `public.communities`).
///
/// Parent umbrella Communities live in `community_hubs` ([CommunityHub]).
class Community {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? imageUrl;
  final String? rules;
  final String creatorId;
  final String? hubId;
  final String privacyType;
  final String postingPermission;
  final int memberCount;
  final int followerCount;
  final bool isMember;
  final bool isFollowing;
  final bool isPendingMember;
  final String? myRole;
  final DateTime createdAt;

  const Community({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.city,
    this.state,
    this.postalCode,
    this.imageUrl,
    this.rules,
    required this.creatorId,
    this.hubId,
    this.privacyType = 'public',
    this.postingPermission = 'members',
    this.memberCount = 0,
    this.followerCount = 0,
    this.isMember = false,
    this.isFollowing = false,
    this.isPendingMember = false,
    this.myRole,
    required this.createdAt,
  });

  bool get isPrivate => privacyType == 'private' || privacyType == 'hidden';
  bool get isPublic => privacyType == 'public';

  bool canManageAs(String? profileId) =>
      profileId != null &&
      (profileId == creatorId ||
          myRole == 'owner' ||
          myRole == 'admin');

  bool get isLeaderRole =>
      myRole == 'owner' || myRole == 'admin' || myRole == 'moderator';

  String? get locationLabel {
    final parts =
        [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  factory Community.fromRow(
    Map<String, dynamic> row, {
    bool isMember = false,
    bool isFollowing = false,
    bool isPendingMember = false,
    String? myRole,
  }) {
    final createdRaw = row['created_at'];
    final storagePath = row['image_storage_path'] as String?;
    final legacy = row['image_url'] as String?;
    return Community(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Group',
      description: row['description'] as String?,
      category: row['category'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      postalCode: row['postal_code'] as String?,
      // Temporary raw value; call [withResolvedImage] before display.
      imageUrl: storagePath?.trim().isNotEmpty == true ? storagePath : legacy,
      rules: row['rules'] as String?,
      creatorId: (row['creator_id'] as String?) ?? '',
      hubId: row['hub_id'] as String?,
      privacyType: (row['privacy_type'] as String?) ?? 'public',
      postingPermission: (row['posting_permission'] as String?) ?? 'members',
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      isMember: isMember,
      isFollowing: isFollowing,
      isPendingMember: isPendingMember,
      myRole: myRole,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
    );
  }

  Future<Community> withResolvedImage() async {
    final resolved = await EntityImageUrl.resolve(
      storagePath: EntityImageUrl.looksLikeStoragePath(imageUrl) ? imageUrl : null,
      legacyUrl: imageUrl,
      provider: MediaStorageProvider.supabase,
    );
    if (resolved == imageUrl) return this;
    return copyWith(imageUrl: resolved);
  }

  Community copyWith({
    bool? isMember,
    bool? isFollowing,
    bool? isPendingMember,
    String? imageUrl,
    String? description,
    String? privacyType,
    String? hubId,
    int? memberCount,
    int? followerCount,
    String? myRole,
  }) {
    return Community(
      id: id,
      name: name,
      description: description ?? this.description,
      category: category,
      city: city,
      state: state,
      postalCode: postalCode,
      imageUrl: imageUrl ?? this.imageUrl,
      rules: rules,
      creatorId: creatorId,
      hubId: hubId ?? this.hubId,
      privacyType: privacyType ?? this.privacyType,
      postingPermission: postingPermission,
      memberCount: memberCount ?? this.memberCount,
      followerCount: followerCount ?? this.followerCount,
      isMember: isMember ?? this.isMember,
      isFollowing: isFollowing ?? this.isFollowing,
      isPendingMember: isPendingMember ?? this.isPendingMember,
      myRole: myRole ?? this.myRole,
      createdAt: createdAt,
    );
  }
}

class CommunityMember {
  final String userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String role;
  final String status;
  final DateTime joinedAt;

  const CommunityMember({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    required this.role,
    this.status = 'active',
    required this.joinedAt,
  });

  bool get isGroupLeader => role == 'owner' || role == 'admin';

  String get roleLabel {
    switch (role) {
      case 'owner':
        return 'Group Leader';
      case 'admin':
        return 'Admin';
      case 'moderator':
        return 'Moderator';
      default:
        return 'Member';
    }
  }
}

class CommunityService {
  CommunityService._();

  static final _client = Supabase.instance.client;

  static const _communityColumns =
      'id, name, description, category, city, state, postal_code, image_url, '
      'image_storage_path, image_storage_provider, '
      'rules, creator_id, hub_id, privacy_type, posting_permission, '
      'member_count, follower_count, created_at';

  static const _communityColumnsLegacy =
      'id, name, description, category, city, state, postal_code, image_url, '
      'rules, creator_id, hub_id, privacy_type, posting_permission, '
      'member_count, follower_count, created_at';

  static Future<List<Map<String, dynamic>>> _selectCommunityRows({
    required dynamic Function(dynamic query) configure,
  }) async {
    Future<List<Map<String, dynamic>>> run(String columns) async {
      dynamic query = _client.from('communities').select(columns);
      query = configure(query);
      final rows = await query;
      return List<Map<String, dynamic>>.from(rows as List);
    }

    try {
      return await run(_communityColumns);
    } catch (_) {
      return await run(_communityColumnsLegacy);
    }
  }

  static Future<List<Community>> _resolveCommunityImages(
    List<Community> communities,
  ) async {
    return Future.wait(communities.map((c) => c.withResolvedImage()));
  }

  static Map<String, dynamic> _imagePersistPayload(MediaUploadResult upload) {
    return {
      // Durable storage path (also written to image_url for pre-migration DBs).
      'image_url': upload.path,
      'image_storage_path': upload.path,
      'image_storage_provider': upload.provider.value,
    };
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

  static Future<Map<String, String>> _myMembershipMeta() async {
    final me = _client.auth.currentUser;
    if (me == null) return {};

    try {
      final rows = await _client
          .from('community_members')
          .select('community_id, role, status')
          .eq('profile_id', me.id);
      final map = <String, String>{};
      for (final row in rows) {
        final id = row['community_id'] as String;
        final status = (row['status'] as String?) ?? 'active';
        final role = (row['role'] as String?) ?? 'member';
        map[id] = '$status|$role';
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _myMembershipIds() async {
    final meta = await _myMembershipMeta();
    return meta.entries
        .where((e) => e.value.startsWith('active|'))
        .map((e) => e.key)
        .toSet();
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

  /// Group IDs the signed-in user joined and/or follows (for Community Feed).
  static Future<Set<String>> fetchMyCommunityFeedIds() async {
    final memberIds = await _myMembershipIds();
    final followIds = await _myFollowIds();
    return {...memberIds, ...followIds};
  }

  static Community _mapRow(
    Map<String, dynamic> row, {
    required Set<String> memberIds,
    required Set<String> followIds,
    required Set<String> pendingIds,
    required Map<String, String> membershipMeta,
  }) {
    final id = row['id'] as String;
    final meta = membershipMeta[id];
    String? role;
    if (meta != null && meta.contains('|')) {
      role = meta.split('|').last;
    }
    return Community.fromRow(
      row,
      isMember: memberIds.contains(id),
      isFollowing: followIds.contains(id),
      isPendingMember: pendingIds.contains(id),
      myRole: role,
    );
  }

  static Future<List<Community>> fetchCommunities({int limit = 50}) async {
    try {
      final rows = await _selectCommunityRows(
        configure: (query) =>
            query.order('created_at', ascending: false).limit(limit),
      );

      final membershipMeta = await _myMembershipMeta();
      final memberIds = membershipMeta.entries
          .where((e) => e.value.startsWith('active|'))
          .map((e) => e.key)
          .toSet();
      final pendingIds = membershipMeta.entries
          .where((e) => e.value.startsWith('pending|'))
          .map((e) => e.key)
          .toSet();
      final followIds = await _myFollowIds();

      final mapped = rows
          .map(
            (row) => _mapRow(
              row,
              memberIds: memberIds,
              followIds: followIds,
              pendingIds: pendingIds,
              membershipMeta: membershipMeta,
            ),
          )
          .toList();
      return await _resolveCommunityImages(mapped);
    } catch (_) {
      return const [];
    }
  }

  static Future<Community?> fetchCommunityById(String id) async {
    if (id.trim().isEmpty) return null;

    try {
      final rows = await _selectCommunityRows(
        configure: (query) => query.eq('id', id).limit(1),
      );
      if (rows.isEmpty) return null;
      final row = rows.first;

      final membershipMeta = await _myMembershipMeta();
      final memberIds = membershipMeta.entries
          .where((e) => e.value.startsWith('active|'))
          .map((e) => e.key)
          .toSet();
      final pendingIds = membershipMeta.entries
          .where((e) => e.value.startsWith('pending|'))
          .map((e) => e.key)
          .toSet();
      final followIds = await _myFollowIds();

      return await _mapRow(
        row,
        memberIds: memberIds,
        followIds: followIds,
        pendingIds: pendingIds,
        membershipMeta: membershipMeta,
      ).withResolvedImage();
    } catch (_) {
      return null;
    }
  }

  static Future<List<Community>> fetchGroupsForHub(
    String hubId, {
    int limit = 40,
  }) async {
    if (hubId.trim().isEmpty) return const [];
    try {
      final rows = await _selectCommunityRows(
        configure: (query) => query
            .eq('hub_id', hubId)
            .order('created_at', ascending: false)
            .limit(limit),
      );

      final membershipMeta = await _myMembershipMeta();
      final memberIds = membershipMeta.entries
          .where((e) => e.value.startsWith('active|'))
          .map((e) => e.key)
          .toSet();
      final pendingIds = membershipMeta.entries
          .where((e) => e.value.startsWith('pending|'))
          .map((e) => e.key)
          .toSet();
      final followIds = await _myFollowIds();

      final mapped = rows
          .map(
            (row) => _mapRow(
              row,
              memberIds: memberIds,
              followIds: followIds,
              pendingIds: pendingIds,
              membershipMeta: membershipMeta,
            ),
          )
          .toList();
      return await _resolveCommunityImages(mapped);
    } catch (_) {
      return const [];
    }
  }

  static Future<Community> createCommunity({
    required String name,
    String? description,
    String? category,
    String? city,
    String? state,
    String? postalCode,
    String privacyType = 'public',
    String? rules,
    String? hubId,
    XFile? imageFile,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to create a group.');

    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Group name is required.');

    final privacy = ['public', 'private', 'hidden'].contains(privacyType)
        ? privacyType
        : 'public';

    await _ensureProfile(me);

    MediaUploadResult? upload;
    if (imageFile != null) {
      upload = await CommunityMediaService.uploadGroupImage(
        communityIdHint: me.id,
        file: imageFile,
      );
    }

    final insert = <String, dynamic>{
      'name': trimmed,
      'description': description?.trim(),
      'category': category?.trim(),
      'city': city?.trim(),
      'state': state?.trim(),
      'postal_code': postalCode?.trim(),
      'rules': rules?.trim(),
      'privacy_type': privacy,
      'creator_id': me.id,
      'member_count': 1,
      'follower_count': 0,
    };
    if (upload != null) {
      insert.addAll(_imagePersistPayload(upload));
    }
    if (hubId != null && hubId.trim().isNotEmpty) {
      insert['hub_id'] = hubId.trim();
    }

    Map<String, dynamic> row;
    try {
      row = await _client
          .from('communities')
          .insert(insert)
          .select(_communityColumns)
          .single();
    } catch (_) {
      insert.remove('image_storage_path');
      insert.remove('image_storage_provider');
      row = await _client
          .from('communities')
          .insert(insert)
          .select(_communityColumnsLegacy)
          .single();
    }

    // Creator becomes the Group Leader (owner).
    try {
      await _client.from('community_members').insert({
        'community_id': row['id'],
        'profile_id': me.id,
        'role': 'owner',
        'status': 'active',
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }

    return Community.fromRow(row, isMember: true, myRole: 'owner')
        .withResolvedImage();
  }

  static Future<Community> updateCommunity({
    required String communityId,
    String? name,
    String? description,
    String? category,
    String? city,
    String? state,
    String? postalCode,
    String? privacyType,
    String? rules,
    String? hubId,
    bool clearHubId = false,
    bool clearImage = false,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to update a group.');

    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) patch['name'] = name.trim();
    if (description != null) patch['description'] = description.trim();
    if (category != null) patch['category'] = category.trim();
    if (city != null) patch['city'] = city.trim();
    if (state != null) patch['state'] = state.trim();
    if (postalCode != null) patch['postal_code'] = postalCode.trim();
    if (privacyType != null &&
        ['public', 'private', 'hidden'].contains(privacyType)) {
      patch['privacy_type'] = privacyType;
    }
    if (rules != null) patch['rules'] = rules.trim();
    if (clearHubId) {
      patch['hub_id'] = null;
    } else if (hubId != null) {
      patch['hub_id'] = hubId.trim().isEmpty ? null : hubId.trim();
    }
    if (clearImage) {
      patch['image_url'] = null;
      patch['image_storage_path'] = null;
    }

    try {
      final row = await _client
          .from('communities')
          .update(patch)
          .eq('id', communityId)
          .select(_communityColumns)
          .single();
      return (await fetchCommunityById(communityId)) ??
          await Community.fromRow(row, isMember: true).withResolvedImage();
    } catch (_) {
      patch.remove('image_storage_path');
      final row = await _client
          .from('communities')
          .update(patch)
          .eq('id', communityId)
          .select(_communityColumnsLegacy)
          .single();
      return (await fetchCommunityById(communityId)) ??
          await Community.fromRow(row, isMember: true).withResolvedImage();
    }
  }

  static Future<Community> updateCommunityImage({
    required String communityId,
    required XFile file,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to update group image.');

    final upload = await CommunityMediaService.uploadGroupImage(
      communityIdHint: communityId,
      file: file,
    );
    final patch = {
      ..._imagePersistPayload(upload),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await _client.from('communities').update(patch).eq('id', communityId);
    } catch (_) {
      patch.remove('image_storage_path');
      patch.remove('image_storage_provider');
      await _client.from('communities').update(patch).eq('id', communityId);
    }

    return (await fetchCommunityById(communityId)) ??
        await Community.fromRow({
          'id': communityId,
          'name': 'Group',
          'creator_id': me.id,
          'created_at': DateTime.now().toIso8601String(),
          ...patch,
        }, isMember: true).withResolvedImage();
  }

  static Future<Community> removeCommunityImage(String communityId) async {
    return updateCommunity(communityId: communityId, clearImage: true);
  }

  /// Join a public group, or request membership for a private group.
  static Future<void> join(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to join a group.');

    await _ensureProfile(me);

    final community = await fetchCommunityById(communityId);
    final status = community?.isPrivate == true ? 'pending' : 'active';

    try {
      await _client.from('community_members').insert({
        'community_id': communityId,
        'profile_id': me.id,
        'role': 'member',
        'status': status,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  static Future<void> cancelJoinRequest(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to cancel request.');

    await _client
        .from('community_members')
        .delete()
        .eq('community_id', communityId)
        .eq('profile_id', me.id)
        .eq('status', 'pending');
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

  static Future<void> reviewMembership({
    required String communityId,
    required String profileId,
    required bool approve,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to review membership.');

    if (approve) {
      await _client
          .from('community_members')
          .update({'status': 'active'})
          .eq('community_id', communityId)
          .eq('profile_id', profileId)
          .eq('status', 'pending');
    } else {
      await _client
          .from('community_members')
          .delete()
          .eq('community_id', communityId)
          .eq('profile_id', profileId)
          .eq('status', 'pending');
    }
  }

  static Future<bool> isFollowing(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null || communityId.trim().isEmpty) return false;
    try {
      final row = await _client
          .from('community_follows')
          .select('community_id')
          .eq('community_id', communityId)
          .eq('profile_id', me.id)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

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
    String status = 'active',
  }) async {
    if (communityId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('community_members')
          .select(
            'profile_id, role, status, joined_at, '
            'profiles(display_name, username, avatar_url)',
          )
          .eq('community_id', communityId)
          .eq('status', status)
          .order('joined_at', ascending: true)
          .limit(limit);

      return rows.map(_mapMember).toList();
    } catch (_) {
      // Fallback if avatar_url column is missing on older schemas.
      try {
        final rows = await _client
            .from('community_members')
            .select(
              'profile_id, role, status, joined_at, '
              'profiles(display_name, username)',
            )
            .eq('community_id', communityId)
            .eq('status', status)
            .order('joined_at', ascending: true)
            .limit(limit);
        return rows.map(_mapMember).toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static CommunityMember _mapMember(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final joinedRaw = row['joined_at'];
    return CommunityMember(
      userId: row['profile_id'] as String,
      displayName: (profile?['display_name'] as String?) ?? 'FirstVue member',
      username: profile?['username'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      role: (row['role'] as String?) ?? 'member',
      status: (row['status'] as String?) ?? 'active',
      joinedAt: joinedRaw is String
          ? DateTime.tryParse(joinedRaw) ?? DateTime.now()
          : joinedRaw is DateTime
              ? joinedRaw
              : DateTime.now(),
    );
  }

  /// Primary Group Leader: owner role, else creator.
  static Future<CommunityMember?> fetchGroupLeader(String communityId) async {
    final members = await fetchMembers(communityId, limit: 30);
    final owner = members.where((m) => m.role == 'owner').toList();
    if (owner.isNotEmpty) return owner.first;
    final admin = members.where((m) => m.role == 'admin').toList();
    if (admin.isNotEmpty) return admin.first;

    final community = await fetchCommunityById(communityId);
    if (community == null || community.creatorId.isEmpty) return null;

    try {
      final profile = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .eq('id', community.creatorId)
          .maybeSingle();
      if (profile == null) return null;
      return CommunityMember(
        userId: profile['id'] as String,
        displayName:
            (profile['display_name'] as String?) ?? 'FirstVue member',
        username: profile['username'] as String?,
        avatarUrl: profile['avatar_url'] as String?,
        role: 'owner',
        joinedAt: community.createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> requestAddGroupToHub({
    required String communityId,
    required String hubId,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to request adding a group.');
    }

    await _client.from('community_group_link_requests').upsert({
      'hub_id': hubId,
      'community_id': communityId,
      'requested_by_profile_id': me.id,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<String?> fetchGroupLinkRequestStatus({
    required String communityId,
    required String hubId,
  }) async {
    try {
      final row = await _client
          .from('community_group_link_requests')
          .select('status')
          .eq('community_id', communityId)
          .eq('hub_id', hubId)
          .maybeSingle();
      return row?['status'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Groups the signed-in user created or joined.
  static Future<List<Community>> fetchYourCommunities({int limit = 20}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final memberRows = await _client
          .from('community_members')
          .select('community_id')
          .eq('profile_id', me.id)
          .eq('status', 'active')
          .limit(limit);

      final createdRows = await _client
          .from('communities')
          .select('id')
          .eq('creator_id', me.id)
          .limit(limit);

      final ids = <String>{
        ...memberRows.map((r) => r['community_id'] as String),
        ...createdRows.map((r) => r['id'] as String),
      }.toList();

      if (ids.isEmpty) return const [];

      final rows = await _selectCommunityRows(
        configure: (query) => query
            .inFilter('id', ids)
            .order('created_at', ascending: false)
            .limit(limit),
      );

      final membershipMeta = await _myMembershipMeta();
      final followIds = await _myFollowIds();
      final mapped = rows
          .map(
            (row) => _mapRow(
              row,
              memberIds: ids.toSet(),
              followIds: followIds,
              pendingIds: const {},
              membershipMeta: membershipMeta,
            ),
          )
          .toList();
      return await _resolveCommunityImages(mapped);
    } catch (_) {
      return const [];
    }
  }

  /// Nearby groups based on user city/state preferences.
  static Future<List<Community>> fetchNearbyCommunities({
    int limit = 20,
  }) async {
    try {
      final prefs = await UserPreferencesService.fetch();
      final city = prefs.locationCity?.trim();
      final state = prefs.locationState?.trim();

      final rows = await _selectCommunityRows(
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

      final membershipMeta = await _myMembershipMeta();
      final memberIds = membershipMeta.entries
          .where((e) => e.value.startsWith('active|'))
          .map((e) => e.key)
          .toSet();
      final pendingIds = membershipMeta.entries
          .where((e) => e.value.startsWith('pending|'))
          .map((e) => e.key)
          .toSet();
      final followIds = await _myFollowIds();

      final mapped = rows
          .where((row) => !memberIds.contains(row['id'] as String))
          .map(
            (row) => _mapRow(
              row,
              memberIds: memberIds,
              followIds: followIds,
              pendingIds: pendingIds,
              membershipMeta: membershipMeta,
            ),
          )
          .toList();
      return await _resolveCommunityImages(mapped);
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

class CommunityMediaService {
  CommunityMediaService._();

  static const _maxBytes = 10 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  /// Uploads a group profile image and returns the durable storage path.
  static Future<MediaUploadResult> uploadGroupImage({
    required String communityIdHint,
    required XFile file,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to upload a group image.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const StorageException('Selected file is empty.');
    if (bytes.length > _maxBytes) {
      throw const StorageException('Group image must be 10 MB or smaller.');
    }

    final mediaType = mediaTypeForFile(file);
    if (mediaType != 'image') {
      throw const StorageException('Group profile image must be a photo.');
    }

    return MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: bytes,
      contentType: mimeTypeForFile(file, mediaType),
      fileName: file.name,
      index: 0,
      subfolder: 'community-avatars/$communityIdHint',
      context: {'profile_id': user.id},
    );
  }

  static Future<MediaUploadResult> uploadHubImage({
    required String hubIdHint,
    required XFile file,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to upload a community image.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const StorageException('Selected file is empty.');
    if (bytes.length > _maxBytes) {
      throw const StorageException('Community image must be 10 MB or smaller.');
    }

    final mediaType = mediaTypeForFile(file);
    if (mediaType != 'image') {
      throw const StorageException('Community profile image must be a photo.');
    }

    return MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: bytes,
      contentType: mimeTypeForFile(file, mediaType),
      fileName: file.name,
      index: 0,
      subfolder: 'community-hub-avatars/$hubIdHint',
      context: {'profile_id': user.id},
    );
  }
}
