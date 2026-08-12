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

  const ProfileMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
    required this.featuredForTrending,
  });

  bool get isVideo => mediaType == 'video';
}

class ProfileMediaService {
  ProfileMediaService._();

  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Future<List<ProfileMediaItem>> fetchMyMedia() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final rows = await _client
        .from('profile_media')
        .select(
          'id, storage_path, storage_provider, media_type, featured_for_trending',
        )
        .eq('profile_id', user.id)
        .order('sort_order')
        .order('created_at');

    return Future.wait(
      rows.map((row) async {
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
          signedUrl: await MediaStorageService.createReadUrl(
            bucket: MediaBucket.profile,
            path: path,
            provider: provider,
            context: {'profile_id': user.id},
          ),
        );
      }),
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
        .order('sort_order', ascending: false)
        .limit(1);
    final firstSortOrder = existing.isEmpty
        ? 0
        : (existing.first['sort_order'] as int) + 1;

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
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
        context: {'profile_id': user.id},
      );
      try {
        await _client.from('profile_media').insert({
          'profile_id': user.id,
          'storage_path': upload.path,
          'storage_provider': upload.provider.value,
          'media_type': mediaType,
          'sort_order': firstSortOrder + index,
        });
      } catch (_) {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.profile,
          path: upload.path,
          provider: upload.provider,
          context: {'profile_id': user.id},
        );
        rethrow;
      }
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
