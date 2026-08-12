import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_type_helpers.dart';
import 'media_storage_service.dart';

class CommunityNewsMediaItem {
  final String id;
  final String storagePath;
  final String signedUrl;
  final MediaStorageProvider storageProvider;
  final String mediaType;

  const CommunityNewsMediaItem({
    required this.id,
    required this.storagePath,
    required this.signedUrl,
    required this.storageProvider,
    required this.mediaType,
  });

  bool get isVideo => mediaType == 'video';
}

class CommunityNewsMediaService {
  CommunityNewsMediaService._();

  static const _maxMediaBytes = 50 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Future<Map<String, List<CommunityNewsMediaItem>>> fetchMediaByPostIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    try {
      final rows = await _client
          .from('community_news_post_media')
          .select('id, post_id, storage_path, storage_provider, media_type, sort_order')
          .inFilter('post_id', postIds)
          .order('sort_order')
          .order('created_at');

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final postId = row['post_id'] as String;
        grouped.putIfAbsent(postId, () => []).add(row);
      }

      final result = <String, List<CommunityNewsMediaItem>>{};
      for (final entry in grouped.entries) {
        final items = <CommunityNewsMediaItem>[];
        for (final row in entry.value) {
          try {
            final path = row['storage_path'] as String;
            final provider = MediaStorageProvider.parse(
              row['storage_provider'] as String?,
            );
            items.add(
              CommunityNewsMediaItem(
                id: row['id'] as String,
                storagePath: path,
                storageProvider: provider,
                mediaType: (row['media_type'] as String?) ?? 'image',
                signedUrl: await MediaStorageService.createReadUrl(
                  bucket: MediaBucket.communityNews,
                  path: path,
                  provider: provider,
                  context: {'post_id': entry.key},
                ),
              ),
            );
          } catch (_) {
            // Skip broken media rows so text posts still load.
          }
        }
        if (items.isNotEmpty) {
          result[entry.key] = items;
        }
      }
      return result;
    } catch (_) {
      // Table or policy may not exist yet — posts still load without attachments.
      return {};
    }
  }

  static Future<List<CommunityNewsMediaItem>> uploadMedia({
    required String postId,
    required List<XFile> files,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding photos or videos.');
    }

    final items = <CommunityNewsMediaItem>[];
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
        bucket: MediaBucket.communityNews,
        bytes: bytes,
        contentType: contentType,
        fileName: file.name,
        index: index,
        context: {'post_id': postId},
      );

      try {
        final row = await _client
            .from('community_news_post_media')
            .insert({
              'post_id': postId,
              'storage_path': upload.path,
              'storage_provider': upload.provider.value,
              'media_type': mediaType,
              'sort_order': index,
            })
            .select('id, storage_path, storage_provider, media_type')
            .single();

        items.add(
          CommunityNewsMediaItem(
            id: row['id'] as String,
            storagePath: upload.path,
            storageProvider: upload.provider,
            mediaType: mediaType,
            signedUrl: await MediaStorageService.createReadUrl(
              bucket: MediaBucket.communityNews,
              path: upload.path,
              provider: upload.provider,
              context: {'post_id': postId},
            ),
          ),
        );
      } catch (_) {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.communityNews,
          path: upload.path,
          provider: upload.provider,
          context: {'post_id': postId},
        );
        rethrow;
      }
    }
    return items;
  }
}
