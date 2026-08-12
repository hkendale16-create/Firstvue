import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_type_helpers.dart';

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
    return MediaStorageService.createReadUrl(
      bucket: MediaBucket.event,
      path: storagePath,
      provider: MediaStorageProvider.parse(storageProvider),
      context: {'event_id': eventId},
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

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > _maxBytes) {
      throw const StorageException('Event photos must be 10 MB or smaller.');
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

    final contentType = mimeTypeForFile(file, 'image');
    final upload = await MediaStorageService.uploadBytes(
      bucket: MediaBucket.event,
      bytes: bytes,
      contentType: contentType,
      fileName: file.name,
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
      await MediaStorageService.deleteObject(
        bucket: MediaBucket.event,
        path: upload.path,
        provider: upload.provider,
        context: {'event_id': eventId},
      );
      rethrow;
    }

    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        await MediaStorageService.deleteObject(
          bucket: MediaBucket.event,
          path: oldPath,
          provider: oldProvider,
          context: {'event_id': eventId},
        );
      } catch (_) {}
    }
  }
}
