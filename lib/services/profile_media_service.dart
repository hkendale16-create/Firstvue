import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';

class ProfileMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;
  final bool featuredForTrending;
  final String mediaRole;

  const ProfileMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
    required this.featuredForTrending,
    this.mediaRole = 'gallery',
  });

  bool get isVideo => mediaType == 'video';
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
      'id, storage_path, storage_provider, media_type, featured_for_trending, media_role';

  static Future<List<ProfileMediaItem>> fetchMyMedia() =>
      fetchGalleryMedia();

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

      return _mapRows(rows, user.id);
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

      return _mapRows(rows, user.id);
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
          .select(_selectColumns)
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

      return _mapRows(rows, profileId);
    } catch (_) {
      final rows = await _client
          .from('profile_media')
          .select(
            'id, storage_path, storage_provider, media_type, featured_for_trending',
          )
          .eq('profile_id', profileId)
          .order('sort_order')
          .order('created_at');

      return _mapRows(rows, profileId);
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
      signedUrl: await MediaStorageService.createReadUrl(
        bucket: MediaBucket.profile,
        path: path,
        provider: provider,
        context: {'profile_id': userId},
      ),
    );
  }

  static Future<void> uploadMedia(List<XFile> files) async {
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
      await _uploadSingle(
        file: files[index],
        userId: user.id,
        index: index,
        sortOrder: firstSortOrder + index,
        mediaRole: 'gallery',
        subfolder: null,
      );
    }
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

  static Future<void> _setRoleImage(
    String userId,
    XFile file, {
    required String role,
    required String subfolder,
  }) async {
    Map<String, dynamic>? existingRow;
    try {
      existingRow = await _client
          .from('profile_media')
          .select('id, storage_path, storage_provider')
          .eq('profile_id', userId)
          .eq('media_role', role)
          .maybeSingle();
    } catch (_) {
      existingRow = null;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > _maxMediaBytes) {
      throw const StorageException(
        'Each photo or video must be 50 MB or smaller.',
      );
    }

    final mediaType = mediaTypeForFile(file);
    final contentType = mimeTypeForFile(file, mediaType);
    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
      index: 0,
      subfolder: subfolder,
      context: {'profile_id': userId},
    );

    final payload = {
      'storage_path': upload.path,
      'storage_provider': upload.provider.value,
      'media_type': mediaType,
      'sort_order': 0,
      'media_role': role,
    };

    try {
      if (existingRow == null) {
        try {
          await _client.from('profile_media').insert({
            'profile_id': userId,
            ...payload,
          });
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          final raced = await _client
              .from('profile_media')
              .select('id, storage_path, storage_provider')
              .eq('profile_id', userId)
              .eq('media_role', role)
              .maybeSingle();
          if (raced == null) rethrow;
          existingRow = raced;
          await _client
              .from('profile_media')
              .update(payload)
              .eq('id', raced['id'] as String);
        }
      } else {
        await _client
            .from('profile_media')
            .update(payload)
            .eq('id', existingRow['id'] as String);
      }
    } catch (_) {
      try {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.profile,
          path: upload.path,
          provider: upload.provider,
          context: {'profile_id': userId},
        );
      } catch (_) {}
      rethrow;
    }

    if (existingRow != null) {
      final oldPath = existingRow['storage_path'] as String?;
      if (oldPath != null &&
          oldPath.isNotEmpty &&
          oldPath != upload.path) {
        try {
          await MediaStorageService.deleteObject(
            bucket: MediaBucket.profile,
            path: oldPath,
            provider: MediaStorageProvider.parse(
              existingRow['storage_provider'] as String?,
            ),
            context: {'profile_id': userId},
          );
        } catch (_) {}
      }
    }
  }

  static Future<void> _removeRoleImage(String role) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to remove this photo.');
    }

    List<dynamic> rows = const [];
    try {
      rows = await _client
          .from('profile_media')
          .select('id, storage_path, storage_provider')
          .eq('profile_id', user.id)
          .eq('media_role', role);
    } catch (_) {
      return;
    }

    for (final row in rows) {
      final path = row['storage_path'] as String?;
      final id = row['id'] as String?;
      if (path == null || id == null) continue;
      try {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.profile,
          path: path,
          provider: MediaStorageProvider.parse(
            row['storage_provider'] as String?,
          ),
          context: {'profile_id': user.id},
        );
      } catch (_) {}
      try {
        await _client.from('profile_media').delete().eq('id', id);
      } catch (_) {}
    }
  }

  static Future<void> _uploadSingle({
    required XFile file,
    required String userId,
    required int index,
    required int sortOrder,
    required String mediaRole,
    required String? subfolder,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > _maxMediaBytes) {
      throw const StorageException(
        'Each photo or video must be 50 MB or smaller.',
      );
    }

    final mediaType = mediaTypeForFile(file);
    final contentType = mimeTypeForFile(file, mediaType);
    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.profile,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
      index: index,
      subfolder: subfolder,
      context: {'profile_id': userId},
    );

    final insertPayload = {
      'profile_id': userId,
      'storage_path': upload.path,
      'storage_provider': upload.provider.value,
      'media_type': mediaType,
      'sort_order': sortOrder,
      'media_role': mediaRole,
    };

    try {
      await _client.from('profile_media').insert(insertPayload);
    } catch (_) {
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
    await MediaStorageService.deleteObject(
      bucket: MediaBucket.profile,
      path: media.storagePath,
      provider: media.storageProvider,
    );
    await _client.from('profile_media').delete().eq('id', media.id);
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
