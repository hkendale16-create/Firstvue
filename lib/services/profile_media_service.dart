import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';
import 'role_media_replace.dart';

class ProfileMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;
  final bool featuredForTrending;
  final String mediaRole;
  final String? caption;

  const ProfileMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
    required this.featuredForTrending,
    this.mediaRole = 'gallery',
    this.caption,
  });

  bool get isVideo =>
      mediaTypeFromMetadata(mediaType: mediaType, pathOrUrl: storagePath) ==
      'video';
}

class ProfileImageSet {
  final ProfileMediaItem? avatar;
  final ProfileMediaItem? cover;

  const ProfileImageSet({this.avatar, this.cover});
}

class ProfileMediaService {
  ProfileMediaService._();

  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static const _selectColumns =
      'id, storage_path, storage_provider, media_type, featured_for_trending, media_role, caption';

  static const _selectColumnsNoCaption =
      'id, storage_path, storage_provider, media_type, featured_for_trending, media_role';

  static Future<List<ProfileMediaItem>> fetchMyMedia() => fetchGalleryMedia();

  static Future<List<ProfileMediaItem>> fetchGalleryMedia() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final rows = await _client
          .from('profile_media')
          .select(_selectColumns)
          .eq('profile_id', user.id)
          .or('media_role.eq.gallery,media_role.is.null')
          .order('sort_order')
          .order('created_at');

      return await _mapRows(rows, user.id);
    } catch (_) {
      try {
        final rows = await _client
            .from('profile_media')
            .select(_selectColumnsNoCaption)
            .eq('profile_id', user.id)
            .or('media_role.eq.gallery,media_role.is.null')
            .order('sort_order')
            .order('created_at');
        return await _mapRows(rows, user.id);
      } catch (_) {
        // media_role column may not exist yet — fall back without role filter.
        final rows = await _client
            .from('profile_media')
            .select(
              'id, storage_path, storage_provider, media_type, featured_for_trending',
            )
            .eq('profile_id', user.id)
            .order('sort_order')
            .order('created_at');

        return await _mapRows(rows, user.id);
      }
    }
  }

  static Future<ProfileImageSet> fetchProfileImages() async {
    final user = _client.auth.currentUser;
    if (user == null) return const ProfileImageSet();
    return fetchProfileImagesForUser(user.id);
  }

  static Future<ProfileImageSet> fetchProfileImagesForUser(
    String profileId,
  ) async {
    if (profileId.trim().isEmpty) return const ProfileImageSet();

    try {
      final rows = await _client
          .from('profile_media')
          .select(_selectColumnsNoCaption)
          .eq('profile_id', profileId)
          .inFilter('media_role', ['avatar', 'cover']);

      ProfileMediaItem? avatar;
      ProfileMediaItem? cover;
      for (final row in rows) {
        final item = await _rowToItem(row, profileId);
        final role = (row['media_role'] as String?) ?? 'gallery';
        if (role == 'avatar') avatar = item;
        if (role == 'cover') cover = item;
      }
      return ProfileImageSet(avatar: avatar, cover: cover);
    } catch (_) {
      return const ProfileImageSet();
    }
  }

  static Future<List<ProfileMediaItem>> fetchGalleryMediaForUser(
    String profileId,
  ) async {
    if (profileId.trim().isEmpty) return const [];

    try {
      final rows = await _client
          .from('profile_media')
          .select(_selectColumns)
          .eq('profile_id', profileId)
          .or('media_role.eq.gallery,media_role.is.null')
          .order('sort_order')
          .order('created_at');

      return await _mapRows(rows, profileId);
    } catch (_) {
      try {
        final rows = await _client
            .from('profile_media')
            .select(_selectColumnsNoCaption)
            .eq('profile_id', profileId)
            .or('media_role.eq.gallery,media_role.is.null')
            .order('sort_order')
            .order('created_at');
        return await _mapRows(rows, profileId);
      } catch (_) {
        final rows = await _client
            .from('profile_media')
            .select(
              'id, storage_path, storage_provider, media_type, featured_for_trending',
            )
            .eq('profile_id', profileId)
            .order('sort_order')
            .order('created_at');

        return await _mapRows(rows, profileId);
      }
    }
  }

  static Future<List<ProfileMediaItem>> _mapRows(
    List<dynamic> rows,
    String userId,
  ) {
    return Future.wait(rows.map((row) => _rowToItem(row, userId)));
  }

  static Future<ProfileMediaItem> _rowToItem(
    Map<String, dynamic> row,
    String userId,
  ) async {
    final path = row['storage_path'] as String;
    final provider = MediaStorageProvider.parse(
      row['storage_provider'] as String?,
    );
    return ProfileMediaItem(
      id: row['id'] as String,
      storagePath: path,
      storageProvider: provider,
      mediaType: (row['media_type'] as String?) ?? 'image',
      featuredForTrending: (row['featured_for_trending'] as bool?) ?? false,
      mediaRole: (row['media_role'] as String?) ?? 'gallery',
      caption: row['caption'] as String?,
      signedUrl: await MediaStorageService.createReadUrl(
        bucket: MediaBucket.profile,
        path: path,
        provider: provider,
        context: {'profile_id': userId},
      ),
    );
  }

  static Future<void> uploadMedia(
    List<XFile> files, {
    List<String?>? captions,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding profile photos.');
    }

    final existing = await _client
        .from('profile_media')
        .select('sort_order')
        .eq('profile_id', user.id)
        .or('media_role.eq.gallery,media_role.is.null')
        .order('sort_order', ascending: false)
        .limit(1);
    final firstSortOrder = existing.isEmpty
        ? 0
        : (existing.first['sort_order'] as int) + 1;

    for (var index = 0; index < files.length; index++) {
      final caption = (captions != null && index < captions.length)
          ? captions[index]
          : null;
      await _uploadSingle(
        file: files[index],
        userId: user.id,
        index: index,
        sortOrder: firstSortOrder + index,
        mediaRole: 'gallery',
        subfolder: null,
        caption: caption,
      );
    }
  }

  static Future<void> updateCaption({
    required String mediaId,
    String? caption,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before editing captions.');
    }
    await _client
        .from('profile_media')
        .update({'caption': caption?.trim()})
        .eq('id', mediaId)
        .eq('profile_id', user.id);
  }

  static Future<void> setAvatar(XFile file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before updating your profile photo.');
    }
    await _setRoleImage(user.id, file, role: 'avatar', subfolder: 'avatar');
  }

  static Future<void> setCover(XFile file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before updating your cover photo.');
    }
    await _setRoleImage(user.id, file, role: 'cover', subfolder: 'cover');
  }

  static Future<void> removeAvatar() => _removeRoleImage('avatar');

  static Future<void> removeCover() => _removeRoleImage('cover');

  static Future<List<Map<String, dynamic>>> _roleRows(
    String profileId,
    String role,
  ) async {
    try {
      final rows = await _client
          .from('profile_media')
          .select(_selectColumnsNoCaption)
          .eq('profile_id', profileId)
          .eq('media_role', role)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      final rows = await _client
          .from('profile_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending',
          )
          .eq('profile_id', profileId)
          .eq('media_role', role)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    }
  }

  static Future<void> _setRoleImage(
    String userId,
    XFile file, {
    required String role,
    required String subfolder,
  }) async {
    final existingRows = await _roleRows(userId, role);
    final existingPaths = <String>{
      for (final row in existingRows) row['storage_path'] as String,
    };

    final validated = await RoleMediaReplace.readValidatedBytes(
      file,
      maxBytes: _maxMediaBytes,
      imagesOnly: true,
    );
    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: validated.bytes,
      contentType: validated.contentType,
      fileName: validated.fileName,
      index: 0,
      subfolder: subfolder,
      context: {'profile_id': userId},
    );

    try {
      final rpcName = role == 'avatar'
          ? 'replace_profile_avatar'
          : 'replace_profile_cover';
      await _client.rpc(
        rpcName,
        params: {
          'p_profile_id': userId,
          'p_storage_path': upload.path,
          'p_storage_provider': upload.provider.value,
          'p_media_type': validated.mediaType,
        },
      );
    } on PostgrestException catch (error) {
      // Only use delete+insert when the atomic RPC is missing.
      if (!RoleMediaReplace.isMissingRpc(error)) {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.profile,
          path: upload.path,
          provider: upload.provider,
          context: {'profile_id': userId},
        );
        rethrow;
      }
      await RoleMediaReplace.upsertInPlace(
        client: _client,
        table: 'profile_media',
        ownerColumn: 'profile_id',
        ownerId: userId,
        role: role,
        storagePath: upload.path,
        storageProvider: upload.provider.value,
        mediaType: validated.mediaType,
      );
    } catch (error) {
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.profile,
        path: upload.path,
        provider: upload.provider,
        context: {'profile_id': userId},
      );
      rethrow;
    }

    for (final path in existingPaths) {
      if (path == upload.path) continue;
      try {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.profile,
          path: path,
          provider: MediaStorageProvider.supabase,
          context: {'profile_id': userId},
        );
      } catch (_) {}
    }
  }

  static Future<void> _removeRoleImage(String role) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to remove this photo.');
    }

    final rows = await _roleRows(user.id, role);
    for (final row in rows) {
      final item = await _rowToItem(row, user.id);
      await deleteMedia(item);
    }
  }

  static Future<void> _uploadSingle({
    required XFile file,
    required String userId,
    required int index,
    required int sortOrder,
    required String mediaRole,
    required String? subfolder,
    String? caption,
  }) async {
    final validated = await RoleMediaReplace.readValidatedBytes(
      file,
      maxBytes: _maxMediaBytes,
    );
    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: validated.bytes,
      contentType: validated.contentType,
      fileName: validated.fileName,
      index: index,
      subfolder: subfolder,
      context: {'profile_id': userId},
    );

    final insertPayload = <String, dynamic>{
      'profile_id': userId,
      'storage_path': upload.path,
      'storage_provider': upload.provider.value,
      'media_type': validated.mediaType,
      'sort_order': sortOrder,
      'media_role': mediaRole,
    };
    final trimmed = caption?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      insertPayload['caption'] = trimmed;
    }

    try {
      await _client.from('profile_media').insert(insertPayload);
    } catch (error) {
      // Older DBs may not have caption yet — retry without it.
      if (trimmed != null && trimmed.isNotEmpty) {
        try {
          insertPayload.remove('caption');
          await _client.from('profile_media').insert(insertPayload);
          return;
        } catch (_) {}
      }
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.profile,
        path: upload.path,
        provider: upload.provider,
        context: {'profile_id': userId},
      );
      rethrow;
    }
  }

  static Future<void> deleteMedia(ProfileMediaItem media) async {
    await _client.from('profile_media').delete().eq('id', media.id);
    try {
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.profile,
        path: media.storagePath,
        provider: media.storageProvider,
      );
    } catch (_) {}
  }

  /// Deletes every photo/video on the signed-in profile so a prototype
  /// account can start over without wiping the database.
  static Future<void> clearMyMedia() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to reset your photos.');
    }

    final rows = await _client
        .from('profile_media')
        .select(_selectColumns)
        .eq('profile_id', user.id);
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      await deleteMedia(await _rowToItem(row, user.id));
    }
  }

  /// Batch-resolve avatar signed URLs for list UIs (profiles.avatar_url DNE).
  static Future<Map<String, String>> fetchAvatarUrlsForProfiles(
    Iterable<String> profileIds,
  ) async {
    final ids = profileIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    try {
      final rows = await _client.rpc(
        'fetch_profile_avatars',
        params: {'p_profile_ids': ids},
      );
      final out = <String, String>{};
      final signJobs = <Future<void>>[];
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final profileId = row['profile_id'] as String?;
        final path = row['storage_path'] as String?;
        if (profileId == null || path == null) continue;
        final provider = MediaStorageProvider.parse(
          row['storage_provider'] as String?,
        );
        signJobs.add(() async {
          try {
            final url = await MediaStorageService.createReadUrl(
              bucket: MediaBucket.profile,
              path: path,
              provider: provider,
              context: {'profile_id': profileId},
            );
            if (url.isNotEmpty) out[profileId] = url;
          } catch (_) {}
        }());
      }
      await Future.wait(signJobs);
      return out;
    } catch (_) {
      // Fallback when RPC is not applied yet — cap concurrency cost.
      final out = <String, String>{};
      await Future.wait(
        ids.map((id) async {
          try {
            final images = await fetchProfileImagesForUser(id);
            final url = images.avatar?.signedUrl;
            if (url != null && url.isNotEmpty) out[id] = url;
          } catch (_) {}
        }),
      );
      return out;
    }
  }

  static Future<void> setFeaturedForTrending(String mediaId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to update trending cover.');
    }

    await _client
        .from('profile_media')
        .update({'featured_for_trending': false})
        .eq('profile_id', user.id);
    await _client
        .from('profile_media')
        .update({'featured_for_trending': true})
        .eq('id', mediaId)
        .eq('profile_id', user.id);
  }
}
