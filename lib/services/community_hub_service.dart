import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String? city;
  final String? state;
  final String? postalCode;
  final String? rules;
  final String visibility;
  final String createdByProfileId;
  final int followerCount;
  final DateTime createdAt;

  const CommunityHub({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.imageUrl,
    this.city,
    this.state,
    this.postalCode,
    this.rules,
    this.visibility = 'public',
    required this.createdByProfileId,
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
      city: row['city'] as String?,
      state: row['state'] as String?,
      postalCode: row['postal_code'] as String?,
      rules: row['rules'] as String?,
      visibility: (row['visibility'] as String?) ?? 'public',
      createdByProfileId: (row['created_by_profile_id'] as String?) ?? '',
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

class CommunityHubService {
  CommunityHubService._();

  static final _client = Supabase.instance.client;

  static const _columns =
      'id, name, description, category, image_url, city, state, postal_code, '
      'rules, visibility, created_by_profile_id, follower_count, created_at';

  static Future<List<CommunityHub>> fetchHubs({int limit = 40}) async {
    try {
      final rows = await _client
          .from('community_hubs')
          .select(_columns)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(CommunityHub.fromRow).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<CommunityHub?> fetchHubById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final row = await _client
          .from('community_hubs')
          .select(_columns)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return CommunityHub.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  static Future<List<CommunityHub>> fetchNearbyHubs({int limit = 16}) async {
    try {
      final prefs = await UserPreferencesService.fetch();
      final city = prefs.locationCity?.trim();
      final state = prefs.locationState?.trim();

      var query = _client.from('community_hubs').select(_columns);

      if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
        query = query.or('city.ilike.%$city%,state.ilike.%$state%');
      } else if (city != null && city.isNotEmpty) {
        query = query.ilike('city', '%$city%');
      } else if (state != null && state.isNotEmpty) {
        query = query.ilike('state', '%$state%');
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit);
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

    final row = await _client
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
        .select(_columns)
        .single();

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
    if (clearImage) patch['image_url'] = null;

    final row = await _client
        .from('community_hubs')
        .update(patch)
        .eq('id', hubId)
        .select(_columns)
        .single();
    return CommunityHub.fromRow(row);
  }

  static Future<CommunityHub> updateHubImage({
    required String hubId,
    required XFile file,
  }) async {
    final imageUrl = await CommunityMediaService.uploadHubImage(
      hubIdHint: hubId,
      file: file,
    );
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
  }

  static Future<CommunityHubLeader?> fetchPrimaryLeader(String hubId) async {
    try {
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
        final hub = await fetchHubById(hubId);
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
