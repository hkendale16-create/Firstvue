import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_type_helpers.dart';
import 'media_storage_service.dart';

class BusinessMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;
  final bool featuredForTrending;

  const BusinessMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
    this.featuredForTrending = false,
  });

  bool get isVideo => mediaType == 'video';
}

class BusinessMediaService {
  BusinessMediaService._();

  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Future<List<BusinessMediaItem>> fetchMedia(String businessId) async {
    final rows = await _client
        .from('business_media')
        .select('id, storage_path, storage_provider, media_type, featured_for_trending')
        .eq('business_id', businessId)
        .order('sort_order')
        .order('created_at');

    return Future.wait(
      rows.map((row) async {
        final path = row['storage_path'] as String;
        final provider = MediaStorageProvider.parse(
          row['storage_provider'] as String?,
        );
        final mediaType = (row['media_type'] as String?) ?? 'image';
        return BusinessMediaItem(
          id: row['id'] as String,
          storagePath: path,
          storageProvider: provider,
          mediaType: mediaType,
          featuredForTrending: (row['featured_for_trending'] as bool?) ?? false,
          signedUrl: await MediaStorageService.createReadUrl(
            bucket: MediaBucket.business,
            path: path,
            provider: provider,
            context: {'business_id': businessId},
          ),
        );
      }),
    );
  }

  static Future<void> uploadMedia({
    required String businessId,
    required List<XFile> files,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding business photos.');
    }

    final existing = await _client
        .from('business_media')
        .select('sort_order')
        .eq('business_id', businessId)
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
        bucket: MediaBucket.business,
        bytes: bytes,
        contentType: contentType,
        fileName: file.name,
        index: index,
        context: {'business_id': businessId},
      );
      try {
        await _client.from('business_media').insert({
          'business_id': businessId,
          'storage_path': upload.path,
          'storage_provider': upload.provider.value,
          'media_type': mediaType,
          'sort_order': firstSortOrder + index,
        });
      } catch (_) {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.business,
          path: upload.path,
          provider: upload.provider,
          context: {'business_id': businessId},
        );
        rethrow;
      }
    }
  }

  static Future<void> deleteMedia(BusinessMediaItem media) async {
    await MediaStorageService.deleteObject(
      bucket: MediaBucket.business,
      path: media.storagePath,
      provider: media.storageProvider,
    );
    await _client.from('business_media').delete().eq('id', media.id);
  }

  static Future<void> setFeaturedForTrending({
    required String businessId,
    required String mediaId,
  }) async {
    await _client
        .from('business_media')
        .update({'featured_for_trending': false})
        .eq('business_id', businessId);
    await _client
        .from('business_media')
        .update({'featured_for_trending': true})
        .eq('id', mediaId)
        .eq('business_id', businessId);
  }
}
