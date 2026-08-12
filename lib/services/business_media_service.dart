import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';

class BusinessMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;

  const BusinessMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
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
        .select('id, storage_path, storage_provider, media_type')
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

      final mediaType = _mediaTypeFor(file);
      final contentType = _mimeTypeFor(file, mediaType);
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

  static String _mediaTypeFor(XFile file) {
    final mimeType = file.mimeType?.toLowerCase() ?? '';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('image/')) return 'image';
    final extension = file.name.split('.').last.toLowerCase();
    const videoExtensions = {'mp4', 'mov', 'webm', 'avi', 'mkv', '3gp', 'm4v'};
    return videoExtensions.contains(extension) ? 'video' : 'image';
  }

  static String _mimeTypeFor(XFile file, String mediaType) {
    final supplied = file.mimeType?.toLowerCase();
    if (supplied != null && supplied.isNotEmpty) {
      return supplied;
    }
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'bmp' => 'image/bmp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      '3gp' => 'video/3gpp',
      'mkv' => 'video/x-matroska',
      'm4v' => 'video/x-m4v',
      _ => mediaType == 'video' ? 'video/mp4' : 'image/jpeg',
    };
  }
}
