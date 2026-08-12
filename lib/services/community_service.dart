import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';
import 'user_preferences_service.dart';

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
    final parts =
        [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
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
      name: (row['name'] as String?) ?? 'Community',
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
          : createdRaw is DateTime
              ? createdRaw
              : DateTime.now(),
    );
  }

  Community copyWith({
    bool? isMember,
    bool? isFollowing,
    String? imageUrl,
    int? memberCount,
  }) {
    return Community(
      id: id,
      name: name,
      description: description,
      city: city,
      state: state,
      imageUrl: imageUrl ?? this.imageUrl,
      creatorId: creatorId,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt,
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
      final rows = await _client
          .from('community_members')
          .select('community_id')
          .eq('profile_id', me.id);
      return rows.map((r) => r['community_id'] as String).toSet();
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

  static Future<List<Community>> fetchCommunities({int limit = 50}) async {
    try {
      final rows = await _client
          .from('communities')
          .select(_communityColumns)
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
          .select(_communityColumns)
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
    XFile? imageFile,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to create a group.');

    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Group name is required.');

    await _ensureProfile(me);

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await CommunityMediaService.uploadGroupImage(
        communityIdHint: me.id,
        file: imageFile,
      );
    }

    final row = await _client
        .from('communities')
        .insert({
          'name': trimmed,
          'description': description?.trim(),
          'city': city?.trim(),
          'state': state?.trim(),
          'image_url': imageUrl,
          'creator_id': me.id,
          'member_count': 1,
        })
        .select(_communityColumns)
        .single();

    // Creator becomes an active member/admin immediately.
    try {
      await _client.from('community_members').insert({
        'community_id': row['id'],
        'profile_id': me.id,
        'role': 'admin',
        'status': 'active',
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }

    return Community.fromRow(row, isMember: true);
  }

  static Future<Community> updateCommunityImage({
    required String communityId,
    required XFile file,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to update group image.');

    final imageUrl = await CommunityMediaService.uploadGroupImage(
      communityIdHint: communityId,
      file: file,
    );

    final row = await _client
        .from('communities')
        .update({'image_url': imageUrl})
        .eq('id', communityId)
        .select(_communityColumns)
        .single();

    final memberIds = await _myMembershipIds();
    final followIds = await _myFollowIds();
    return Community.fromRow(
      row,
      isMember: memberIds.contains(communityId),
      isFollowing: followIds.contains(communityId),
    );
  }

  static Future<void> join(String communityId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to join a group.');

    await _ensureProfile(me);

    try {
      await _client.from('community_members').insert({
        'community_id': communityId,
        'profile_id': me.id,
        'role': 'member',
        'status': 'active',
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
        .eq('profile_id', me.id);
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
  }) async {
    if (communityId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('community_members')
          .select(
            'profile_id, role, joined_at, profiles(display_name, username)',
          )
          .eq('community_id', communityId)
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

  /// Groups the signed-in user created or joined.
  static Future<List<Community>> fetchYourCommunities({int limit = 20}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final memberRows = await _client
          .from('community_members')
          .select('community_id')
          .eq('profile_id', me.id)
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

      final rows = await _client
          .from('communities')
          .select(_communityColumns)
          .inFilter('id', ids)
          .order('created_at', ascending: false)
          .limit(limit);

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

  /// Nearby communities based on user city/state preferences.
  static Future<List<Community>> fetchNearbyCommunities({
    int limit = 20,
  }) async {
    try {
      final prefs = await UserPreferencesService.fetch();
      final city = prefs.locationCity?.trim();
      final state = prefs.locationState?.trim();

      var query = _client.from('communities').select(_communityColumns);

      if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
        query = query.or('city.ilike.%$city%,state.ilike.%$state%');
      } else if (city != null && city.isNotEmpty) {
        query = query.ilike('city', '%$city%');
      } else if (state != null && state.isNotEmpty) {
        query = query.ilike('state', '%$state%');
      }

      final rows =
          await query.order('created_at', ascending: false).limit(limit);

      final memberIds = await _myMembershipIds();
      final followIds = await _myFollowIds();
      final yourIds = memberIds;

      return rows
          .where((row) => !yourIds.contains(row['id'] as String))
          .map(
            (row) => Community.fromRow(
              row,
              isMember: memberIds.contains(row['id'] as String),
              isFollowing: followIds.contains(row['id'] as String),
            ),
          )
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

class CommunityMediaService {
  CommunityMediaService._();

  static const _maxBytes = 10 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  /// Uploads a group profile image under the signed-in user's storage folder
  /// and returns a signed read URL for `communities.image_url`.
  static Future<String> uploadGroupImage({
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

    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: bytes,
      contentType: mimeTypeForFile(file, mediaType),
      fileName: file.name,
      index: 0,
      subfolder: 'community-avatars/$communityIdHint',
      context: {'profile_id': user.id},
    );

    return MediaStorageService.createReadUrl(
      bucket: MediaBucket.profile,
      path: upload.path,
      provider: upload.provider,
      context: {'profile_id': user.id},
    );
  }
}
