import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import '../utils/location_match.dart';
import 'community_editor_service.dart';
import 'community_service.dart';
import 'entity_image_url.dart';
import 'media_storage_service.dart';
import 'profile_cards.dart';
import 'profile_media_service.dart';
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
  final String? metroArea;
  final String? handle;
  final String? rules;
  final String visibility;
  final String createdByProfileId;
  final String? leaderUserId;
  final String status;
  final int followerCount;
  final int memberCount;
  final bool showManagersPublicly;
  final DateTime createdAt;
  final MediaStorageProvider imageStorageProvider;
  final MediaStorageProvider coverStorageProvider;

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
    this.metroArea,
    this.handle,
    this.rules,
    this.visibility = 'public',
    required this.createdByProfileId,
    this.leaderUserId,
    this.status = 'active',
    this.followerCount = 0,
    this.memberCount = 0,
    this.showManagersPublicly = false,
    required this.createdAt,
    this.imageStorageProvider = MediaStorageProvider.supabase,
    this.coverStorageProvider = MediaStorageProvider.supabase,
  });

  String? get locationLabel {
    final parts = [
      city,
      state,
      if ((metroArea ?? '').trim().isNotEmpty && metroArea != city) metroArea,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.take(2).join(', ');
  }

  bool get isActive => status == 'active';
  bool get isPublic => visibility == 'public';
  bool get isDiscoverable => isActive && isPublic;

  factory CommunityHub.fromRow(Map<String, dynamic> row) {
    final createdRaw = row['created_at'];
    final storagePath = row['image_storage_path'] as String?;
    final legacyImage = row['image_url'] as String?;
    final coverStoragePath = row['cover_storage_path'] as String?;
    final legacyCover = row['cover_url'] as String?;
    return CommunityHub(
      id: row['id'] as String,
      name: (row['name'] as String?) ?? 'Community',
      description: row['description'] as String?,
      category: row['category'] as String?,
      // Temporary raw value; call [withResolvedImages] before display.
      imageUrl: storagePath?.trim().isNotEmpty == true
          ? storagePath
          : legacyImage,
      coverUrl: coverStoragePath?.trim().isNotEmpty == true
          ? coverStoragePath
          : legacyCover,
      city: row['city'] as String?,
      state: row['state'] as String?,
      postalCode: row['postal_code'] as String?,
      metroArea: row['metro_area'] as String?,
      handle: row['handle'] as String?,
      rules: row['rules'] as String?,
      visibility: (row['visibility'] as String?) ?? 'public',
      createdByProfileId: (row['created_by_profile_id'] as String?) ?? '',
      leaderUserId: row['leader_user_id'] as String?,
      status: (row['status'] as String?) ?? 'active',
      followerCount: (row['follower_count'] as num?)?.toInt() ?? 0,
      memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
      showManagersPublicly: row['show_managers_publicly'] as bool? ?? false,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : createdRaw is DateTime
          ? createdRaw
          : DateTime.now(),
      imageStorageProvider: MediaStorageProvider.parse(
        row['image_storage_provider'] as String?,
      ),
      coverStorageProvider: MediaStorageProvider.parse(
        row['cover_storage_provider'] as String?,
      ),
    );
  }

  Future<CommunityHub> withResolvedImages() async {
    final resolvedImage = await EntityImageUrl.resolve(
      storagePath: EntityImageUrl.looksLikeStoragePath(imageUrl)
          ? imageUrl
          : null,
      legacyUrl: imageUrl,
      provider: imageStorageProvider,
    );
    final resolvedCover = await EntityImageUrl.resolve(
      storagePath: EntityImageUrl.looksLikeStoragePath(coverUrl)
          ? coverUrl
          : null,
      legacyUrl: coverUrl,
      provider: coverStorageProvider,
    );
    if (resolvedImage == imageUrl && resolvedCover == coverUrl) return this;
    return CommunityHub(
      id: id,
      name: name,
      description: description,
      category: category,
      imageUrl: resolvedImage,
      coverUrl: resolvedCover,
      city: city,
      state: state,
      postalCode: postalCode,
      metroArea: metroArea,
      handle: handle,
      rules: rules,
      visibility: visibility,
      createdByProfileId: createdByProfileId,
      leaderUserId: leaderUserId,
      status: status,
      followerCount: followerCount,
      memberCount: memberCount,
      showManagersPublicly: showManagersPublicly,
      createdAt: createdAt,
      imageStorageProvider: imageStorageProvider,
      coverStorageProvider: coverStorageProvider,
    );
  }

  CommunityHub copyWith({
    String? imageUrl,
    String? coverUrl,
    String? description,
    String? status,
    int? followerCount,
    int? memberCount,
    bool? showManagersPublicly,
    String? leaderUserId,
  }) {
    return CommunityHub(
      id: id,
      name: name,
      description: description ?? this.description,
      category: category,
      imageUrl: imageUrl ?? this.imageUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      city: city,
      state: state,
      postalCode: postalCode,
      metroArea: metroArea,
      handle: handle,
      rules: rules,
      visibility: visibility,
      createdByProfileId: createdByProfileId,
      leaderUserId: leaderUserId ?? this.leaderUserId,
      status: status ?? this.status,
      followerCount: followerCount ?? this.followerCount,
      memberCount: memberCount ?? this.memberCount,
      showManagersPublicly: showManagersPublicly ?? this.showManagersPublicly,
      createdAt: createdAt,
      imageStorageProvider: imageStorageProvider,
      coverStorageProvider: coverStorageProvider,
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
  bool get isApproved => status == 'approved' || status == 'approved_for_feed';
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
      'id, name, description, category, image_url, cover_url, '
      'image_storage_path, image_storage_provider, '
      'cover_storage_path, cover_storage_provider, '
      'city, state, postal_code, metro_area, handle, rules, visibility, '
      'created_by_profile_id, leader_user_id, status, follower_count, '
      'member_count, show_managers_publicly, created_at';

  static const _columnsLegacy =
      'id, name, description, category, image_url, city, state, postal_code, '
      'rules, visibility, created_by_profile_id, follower_count, created_at';

  static const _columnsNoMetro =
      'id, name, description, category, image_url, cover_url, '
      'image_storage_path, image_storage_provider, '
      'cover_storage_path, cover_storage_provider, '
      'city, state, postal_code, rules, visibility, created_by_profile_id, '
      'leader_user_id, status, follower_count, created_at';

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

  static Map<String, dynamic> _imagePersistPayload(MediaUploadResult upload) {
    return {
      'image_url': upload.path,
      'image_storage_path': upload.path,
      'image_storage_provider': upload.provider.value,
    };
  }

  static Map<String, dynamic> _coverPersistPayload(MediaUploadResult upload) {
    return {
      'cover_url': upload.path,
      'cover_storage_path': upload.path,
      'cover_storage_provider': upload.provider.value,
    };
  }

  static const _clearImagePayload = {
    'image_url': null,
    'image_storage_path': null,
    'image_storage_provider': null,
  };

  static const _clearCoverPayload = {
    'cover_url': null,
    'cover_storage_path': null,
    'cover_storage_provider': null,
  };

  static Future<List<CommunityHub>> _resolveHubImages(
    List<CommunityHub> hubs,
  ) async {
    return Future.wait(hubs.map((h) => h.withResolvedImages()));
  }

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
      try {
        return await run(_columnsNoMetro);
      } catch (_) {
        return await run(_columnsLegacy);
      }
    }
  }

  static Future<List<CommunityHub>> fetchHubs({int limit = 40}) async {
    try {
      List<Map<String, dynamic>> rows;
      try {
        rows = await _selectHubRows(
          configure: (query) => query
              .eq('status', 'active')
              .order('created_at', ascending: false)
              .limit(limit),
        );
      } catch (_) {
        rows = await _selectHubRows(
          configure: (query) =>
              query.order('created_at', ascending: false).limit(limit),
        );
      }
      return await _resolveHubImages(rows.map(CommunityHub.fromRow).toList());
    } catch (error, stack) {
      debugPrint('CommunityHubService.fetchHubs failed: $error\n$stack');
      rethrow;
    }
  }

  /// Approved communities the user manages (active hub role) or has joined
  /// through a linked group membership. Pending leader roles are excluded.
  static Future<List<CommunityHub>> fetchYourHubs({int limit = 20}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      List roleRows;
      try {
        roleRows = await _client
            .from('community_hub_roles')
            .select('hub_id')
            .eq('profile_id', me.id)
            .eq('status', 'active')
            .limit(limit);
      } catch (_) {
        // Recursive RLS on community_hub_roles must not blank Communities.
        roleRows = const [];
      }

      final memberGroupRows = await _client
          .from('community_members')
          .select('community_id')
          .eq('profile_id', me.id)
          .eq('status', 'active')
          .limit(80);

      final groupIds = memberGroupRows
          .map((r) => r['community_id'] as String)
          .toList();

      final ids = <String>{...roleRows.map((r) => r['hub_id'] as String)};

      if (groupIds.isNotEmpty) {
        final linkedGroups = await _client
            .from('communities')
            .select('hub_id')
            .inFilter('id', groupIds)
            .not('hub_id', 'is', null)
            .limit(limit);
        for (final row in linkedGroups) {
          final hubId = row['hub_id'] as String?;
          if (hubId != null && hubId.isNotEmpty) ids.add(hubId);
        }
      }

      if (ids.isEmpty) return const [];

      final rows = await _selectHubRows(
        configure: (query) => query
            .inFilter('id', ids.toList())
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return await _resolveHubImages(rows.map(CommunityHub.fromRow).toList());
    } catch (error, stack) {
      debugPrint('CommunityHubService.fetchYourHubs failed: $error\n$stack');
      rethrow;
    }
  }

  /// True when the user has an active management role on the hub.
  /// Pending creators / leaders must not manage.
  static Future<bool> isActiveManager(String hubId, {String? profileId}) async {
    final id = profileId ?? _client.auth.currentUser?.id;
    if (id == null || hubId.trim().isEmpty) return false;
    try {
      final ok = await _client.rpc(
        'is_active_hub_manager',
        params: {'p_hub_id': hubId, 'p_profile_id': id},
      );
      if (ok is bool) return ok;
    } catch (_) {}

    try {
      final row = await _client
          .from('community_hub_roles')
          .select('role, status')
          .eq('hub_id', hubId)
          .eq('profile_id', id)
          .eq('status', 'active')
          .maybeSingle();
      if (row == null) return false;
      final role = (row['role'] as String?) ?? '';
      return role == 'creator' ||
          role == 'lead_leader' ||
          role == 'leader' ||
          role == 'admin';
    } catch (error, stack) {
      debugPrint('CommunityHubService.isActiveManager failed: $error\n$stack');
      return false;
    }
  }

  static Future<bool> hasPendingManagement(
    String hubId, {
    String? profileId,
  }) async {
    final id = profileId ?? _client.auth.currentUser?.id;
    if (id == null || hubId.trim().isEmpty) return false;
    try {
      final row = await _client
          .from('community_hub_roles')
          .select('status')
          .eq('hub_id', hubId)
          .eq('profile_id', id)
          .eq('status', 'pending')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<CommunityHub?> fetchHubById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final rows = await _selectHubRows(
        configure: (query) => query.eq('id', id).limit(1),
      );
      if (rows.isEmpty) return null;
      return await CommunityHub.fromRow(rows.first).withResolvedImages();
    } catch (error, stack) {
      debugPrint('CommunityHubService.fetchHubById failed: $error\n$stack');
      rethrow;
    }
  }

  static Future<List<CommunityHub>> fetchNearbyHubs({int limit = 16}) async {
    try {
      final prefs = await UserPreferencesService.fetch();
      final orFilter = LocationMatch.postgrestOrFilter(prefs);

      if (orFilter == null) {
        return await fetchHubs(limit: limit);
      }

      Future<List<Map<String, dynamic>>> runNearby({
        required bool filterActive,
        required bool applyLocation,
      }) {
        return _selectHubRows(
          configure: (query) {
            var q = query;
            if (filterActive) {
              q = q.eq('status', 'active');
            }
            if (applyLocation) {
              q = q.or(orFilter);
            }
            return q.order('created_at', ascending: false).limit(limit);
          },
        );
      }

      List<Map<String, dynamic>> rows;
      try {
        rows = await runNearby(filterActive: true, applyLocation: true);
      } catch (_) {
        // metro_area may be absent pre-migration; retry without it via legacy.
        try {
          final city = prefs.locationCity?.trim();
          final state = prefs.locationState?.trim();
          rows = await _selectHubRows(
            configure: (query) {
              var q = query.eq('status', 'active');
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
        } catch (_) {
          rows = await runNearby(filterActive: false, applyLocation: false);
        }
      }

      if (rows.isEmpty) {
        debugPrint(
          'CommunityHubService.fetchNearbyHubs: location filter empty; '
          'falling back to active hubs.',
        );
        return await fetchHubs(limit: limit);
      }
      return await _resolveHubImages(rows.map(CommunityHub.fromRow).toList());
    } catch (error, stack) {
      debugPrint('CommunityHubService.fetchNearbyHubs failed: $error\n$stack');
      return await fetchHubs(limit: limit);
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

    MediaUploadResult? upload;
    if (imageFile != null) {
      upload = await CommunityMediaService.uploadHubImage(
        hubIdHint: me.id,
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
      'visibility': visibility == 'private' ? 'private' : 'public',
      'created_by_profile_id': me.id,
      'leader_user_id': me.id,
      'status': 'active',
    };
    if (upload != null) {
      insert.addAll(_imagePersistPayload(upload));
    }

    Map<String, dynamic> row;
    try {
      row = await _client
          .from('community_hubs')
          .insert(insert)
          .select(_columns)
          .single();
    } catch (_) {
      insert.remove('image_storage_path');
      insert.remove('image_storage_provider');
      insert.remove('leader_user_id');
      insert.remove('status');
      row = await _client
          .from('community_hubs')
          .insert(insert)
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

    return await CommunityHub.fromRow(row).withResolvedImages();
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
    bool clearCover = false,
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
    if (clearImage) patch.addAll(_clearImagePayload);
    if (clearCover) patch.addAll(_clearCoverPayload);

    try {
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columns)
          .single();
      return await CommunityHub.fromRow(row).withResolvedImages();
    } catch (_) {
      patch.remove('cover_url');
      patch.remove('status');
      patch.remove('image_storage_path');
      patch.remove('image_storage_provider');
      patch.remove('cover_storage_path');
      patch.remove('cover_storage_provider');
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columnsLegacy)
          .single();
      return await CommunityHub.fromRow(row).withResolvedImages();
    }
  }

  static Future<CommunityHub> updateHubImage({
    required String hubId,
    required XFile file,
  }) async {
    final upload = await CommunityMediaService.uploadHubImage(
      hubIdHint: hubId,
      file: file,
    );
    final patch = {
      ..._imagePersistPayload(upload),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columns)
          .single();
      return await CommunityHub.fromRow(row).withResolvedImages();
    } catch (_) {
      patch.remove('image_storage_path');
      patch.remove('image_storage_provider');
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columnsLegacy)
          .single();
      return await CommunityHub.fromRow(row).withResolvedImages();
    }
  }

  static Future<CommunityHub> updateHubCover({
    required String hubId,
    required XFile file,
  }) async {
    final upload = await CommunityMediaService.uploadHubCover(
      hubIdHint: hubId,
      file: file,
    );
    final patch = {
      ..._coverPersistPayload(upload),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      final row = await _client
          .from('community_hubs')
          .update(patch)
          .eq('id', hubId)
          .select(_columns)
          .single();
      return await CommunityHub.fromRow(row).withResolvedImages();
    } catch (_) {
      // Older schemas may only have cover_url.
      final legacy = {
        'cover_url': upload.path,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final row = await _client
          .from('community_hubs')
          .update(legacy)
          .eq('id', hubId)
          .select(_columnsLegacy)
          .single();
      return await CommunityHub.fromRow(row).withResolvedImages();
    }
  }

  static Future<CommunityHub> removeHubImage(String hubId) async {
    await _deleteHubStoredObject(
      hubId: hubId,
      pathColumn: 'image_storage_path',
      providerColumn: 'image_storage_provider',
      legacyUrlColumn: 'image_url',
    );
    return updateHub(hubId: hubId, clearImage: true);
  }

  static Future<CommunityHub> removeHubCover(String hubId) async {
    await _deleteHubStoredObject(
      hubId: hubId,
      pathColumn: 'cover_storage_path',
      providerColumn: 'cover_storage_provider',
      legacyUrlColumn: 'cover_url',
    );
    return updateHub(hubId: hubId, clearCover: true);
  }

  static Future<void> _deleteHubStoredObject({
    required String hubId,
    required String pathColumn,
    required String providerColumn,
    required String legacyUrlColumn,
  }) async {
    try {
      final row = await _client
          .from('community_hubs')
          .select('$pathColumn, $providerColumn, $legacyUrlColumn')
          .eq('id', hubId)
          .maybeSingle();
      if (row == null) return;
      final path =
          ((row[pathColumn] as String?) ?? (row[legacyUrlColumn] as String?))
              ?.trim();
      if (path == null || path.isEmpty || path.startsWith('http')) return;
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.profile,
        path: path,
        provider: MediaStorageProvider.parse(row[providerColumn] as String?),
        context: {
          'profile_id': _client.auth.currentUser?.id ?? '',
        },
      );
    } catch (_) {}
  }

  static Future<CommunityHubLeader?> fetchPrimaryLeader(String hubId) async {
    try {
      final hub = await fetchHubById(hubId);
      if (hub?.leaderUserId != null && hub!.leaderUserId!.isNotEmpty) {
        final profileId = hub.leaderUserId!;
        final profile = await ProfileCards.fetchById(
          profileId,
          select: ProfileCards.nameColumns,
        );
        final avatars = await ProfileMediaService.fetchAvatarUrlsForProfiles([
          profileId,
        ]);
        return CommunityHubLeader(
          profileId: profileId,
          displayName:
              (profile?['display_name'] as String?) ?? 'FirstVue member',
          username: profile?['username'] as String?,
          avatarUrl: avatars[profileId],
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
        // Do not treat a pending creator / created_by alone as the public leader.
        return null;
      }

      final profileId = chosen['profile_id'] as String;
      final profile = await ProfileCards.fetchById(
        profileId,
        select: ProfileCards.nameColumns,
      );
      final avatars = await ProfileMediaService.fetchAvatarUrlsForProfiles([
        profileId,
      ]);

      return CommunityHubLeader(
        profileId: profileId,
        displayName: (profile?['display_name'] as String?) ?? 'FirstVue member',
        username: profile?['username'] as String?,
        avatarUrl: avatars[profileId],
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

    final status = canPostToCommunityFeed ? 'approved_for_feed' : 'approved';
    final row = await _client
        .from('community_groups')
        .upsert({
          'community_id': hubId,
          'group_id': groupId,
          'status': status,
          'can_post_to_community_feed': canPostToCommunityFeed,
          'approved_by': me.id,
          'approved_at': DateTime.now().toIso8601String(),
          'removed_at': null,
        }, onConflict: 'community_id,group_id')
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
        .upsert({
          'community_id': hubId,
          'group_id': groupId,
          'status': 'pending',
          'can_post_to_community_feed': false,
          'removed_at': null,
        }, onConflict: 'community_id,group_id')
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
    await _client
        .from('community_groups')
        .update({
          'status': 'removed',
          'can_post_to_community_feed': false,
          'removed_at': DateTime.now().toIso8601String(),
        })
        .eq('community_id', hubId)
        .eq('group_id', groupId);
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

    await _client
        .from('community_feed_posts')
        .update({
          'removed_from_community_at': DateTime.now().toIso8601String(),
          'removed_by': me.id,
        })
        .eq('id', feedPostId);
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

  /// Admin: all pending community↔hub group link requests.
  static Future<List<Map<String, dynamic>>>
  fetchAllPendingLinkRequestsForAdmin() async {
    final rows = await _client
        .from('community_group_link_requests')
        .select(
          'id, community_id, hub_id, requested_by_profile_id, status, created_at, '
          'communities(name, image_url), community_hubs(name)',
        )
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> reviewLinkRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _client.rpc(
      'review_community_group_link_request',
      params: {'p_request_id': requestId, 'p_approve': approve},
    );
  }

  static Future<List<Map<String, dynamic>>> fetchPendingHubRoles(
    String hubId,
  ) async {
    try {
      final rows = await _client
          .from('community_hub_roles')
          .select('profile_id, role, status, created_at')
          .eq('hub_id', hubId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(
        (rows as List).map((row) => Map<String, dynamic>.from(row as Map)),
      );
      await ProfileCards.attachAsProfiles(list, idKey: 'profile_id');
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> reviewHubRole({
    required String hubId,
    required String profileId,
    required bool approve,
  }) async {
    await _client.rpc(
      'review_hub_role',
      params: {
        'p_hub_id': hubId,
        'p_profile_id': profileId,
        'p_approve': approve,
      },
    );
  }

  static Future<void> inviteHubLeader({
    required String hubId,
    required String profileId,
    String role = 'leader',
  }) async {
    await _client.rpc(
      'invite_hub_leader',
      params: {'p_hub_id': hubId, 'p_profile_id': profileId, 'p_role': role},
    );
  }

  /// Group id for posting into this Community's newsfeed (managers / editors).
  static Future<String> ensureNewsfeedGroup(String hubId) async {
    final result = await _client.rpc(
      'ensure_hub_newsfeed_group',
      params: {'p_hub_id': hubId},
    );
    if (result is String && result.trim().isNotEmpty) return result;
    throw const AuthException('Could not open Community newsfeed composer.');
  }

  /// True when the signed-in user may compose posts for the hub newsfeed.
  static Future<bool> canPostToNewsfeed(
    String hubId, {
    String? profileId,
    List<CommunityEditor>? editors,
  }) async {
    final id = profileId ?? _client.auth.currentUser?.id;
    if (id == null || hubId.trim().isEmpty) return false;
    if (await isActiveManager(hubId, profileId: id)) return true;
    final list = editors ?? await fetchEditors(hubId);
    return list.any(
      (e) =>
          e.userId == id &&
          e.isActive &&
          e.hasPermission(CommunityEditorPermissions.manageNewsfeed),
    );
  }

  static Future<bool> isFollowing(String hubId) async {
    final me = _client.auth.currentUser;
    if (me == null || hubId.trim().isEmpty) return false;
    try {
      final row = await _client
          .from('community_hub_follows')
          .select('hub_id')
          .eq('hub_id', hubId)
          .eq('profile_id', me.id)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> follow(String hubId) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to follow a Community.');
    }
    try {
      await _client.from('community_hub_follows').insert({
        'hub_id': hubId,
        'profile_id': me.id,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
    return true;
  }

  static Future<bool> unfollow(String hubId) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to unfollow a Community.');
    }
    await _client
        .from('community_hub_follows')
        .delete()
        .eq('hub_id', hubId)
        .eq('profile_id', me.id);
    return false;
  }

  static Future<bool> toggleFollow(
    String hubId, {
    required bool currentlyFollowing,
  }) async {
    if (currentlyFollowing) {
      return unfollow(hubId);
    }
    return follow(hubId);
  }
}
