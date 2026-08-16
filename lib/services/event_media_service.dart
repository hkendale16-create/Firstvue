import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_variant_uploader.dart';
import 'media_variants.dart';
import 'role_media_replace.dart';

class EventMediaService {
  EventMediaService._();

  static const _maxBytes = 10 * 1024 * 1024;
  static final _client = Supabase.instance.client;

  static Future<String?> coverUrlForEvent({
    required String eventId,
    String? storagePath,
    String? storageProvider,
  }) async {
    if (storagePath == null || storagePath.trim().isEmpty) return null;
    return MediaVariantUploader.createDisplayUrl(
      bucket: MediaBucket.event,
      storagePath: storagePath,
      provider: MediaStorageProvider.parse(storageProvider),
      context: {'event_id': eventId},
      preferred: MediaVariant.feed,
    );
  }

  static Future<void> setCover({
    required String eventId,
    required XFile file,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before adding an event photo.');
    }

    final existing = await _client
        .from('community_events')
        .select('cover_storage_path, cover_storage_provider, organizer_id')
        .eq('id', eventId)
        .maybeSingle();
    if (existing == null) {
      throw const StorageException('Event not found.');
    }
    if (existing['organizer_id'] != user.id) {
      throw const AuthException('Only the event organizer can update photos.');
    }

    final oldPath = existing['cover_storage_path'] as String?;
    final oldProvider = MediaStorageProvider.parse(
      existing['cover_storage_provider'] as String?,
    );

    final validated = await RoleMediaReplace.readValidatedBytes(
      file,
      maxBytes: _maxBytes,
      imagesOnly: true,
    );
    final upload = await MediaVariantUploader.uploadImageOrBytes(
      bucket: MediaBucket.event,
      bytes: validated.bytes,
      contentType: validated.contentType,
      fileName: validated.fileName,
      mediaType: validated.mediaType,
      index: 0,
      subfolder: 'cover',
      context: {'event_id': eventId},
    );

    try {
      await _client.from('community_events').update({
        'cover_storage_path': upload.path,
        'cover_storage_provider': upload.provider.value,
      }).eq('id', eventId);
    } catch (_) {
      await MediaVariantUploader.deleteWithVariants(
        bucket: MediaBucket.event,
        storagePath: upload.path,
        provider: upload.provider,
        context: {'event_id': eventId},
        explicitThumbnailPath: upload.thumbnailPath,
      );
      rethrow;
    }

    if (oldPath != null && oldPath.isNotEmpty) {
      await MediaVariantUploader.deleteWithVariants(
        bucket: MediaBucket.event,
        storagePath: oldPath,
        provider: oldProvider,
        context: {'event_id': eventId},
      );
    }
  }

  static Future<void> removeCover(String eventId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before removing an event photo.');
    }

    final existing = await _client
        .from('community_events')
        .select('cover_storage_path, cover_storage_provider, organizer_id')
        .eq('id', eventId)
        .maybeSingle();
    if (existing == null) {
      throw const StorageException('Event not found.');
    }
    if (existing['organizer_id'] != user.id) {
      throw const AuthException('Only the event organizer can update photos.');
    }

    final oldPath = existing['cover_storage_path'] as String?;
    final oldProvider = MediaStorageProvider.parse(
      existing['cover_storage_provider'] as String?,
    );

    await _client.from('community_events').update({
      'cover_storage_path': null,
      'cover_storage_provider': null,
    }).eq('id', eventId);

    if (oldPath != null && oldPath.isNotEmpty) {
      await MediaVariantUploader.deleteWithVariants(
        bucket: MediaBucket.event,
        storagePath: oldPath,
        provider: oldProvider,
        context: {'event_id': eventId},
      );
    }
  }
}
