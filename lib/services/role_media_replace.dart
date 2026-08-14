import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_type_helpers.dart';
import 'media_transcode.dart';

/// Shared helpers for avatar/cover replace flows across entity media tables.
class RoleMediaReplace {
  RoleMediaReplace._();

  static bool isMissingRpc(Object error) {
    return error is PostgrestException && error.code == 'PGRST202';
  }

  static bool isUniqueViolation(Object error) {
    return error is PostgrestException && error.code == '23505';
  }

  /// UPDATE the existing avatar/cover row in place so a unique partial
  /// index (e.g. business_media_one_avatar_idx) is never violated by
  /// delete-then-insert races. Inserts only when no role row exists.
  static Future<void> upsertInPlace({
    required SupabaseClient client,
    required String table,
    required String ownerColumn,
    required String ownerId,
    required String role,
    required String storagePath,
    required String storageProvider,
    required String mediaType,
  }) async {
    final existing = await client
        .from(table)
        .select('id')
        .eq(ownerColumn, ownerId)
        .eq('media_role', role)
        .order('created_at', ascending: false)
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(existing as List);
    final payload = {
      'storage_path': storagePath,
      'storage_provider': storageProvider,
      'media_type': mediaType,
      'sort_order': 0,
    };
    if (rows.isNotEmpty) {
      await client.from(table).update(payload).eq('id', rows.first['id']);
      return;
    }
    try {
      await client.from(table).insert({
        ownerColumn: ownerId,
        'media_role': role,
        ...payload,
      });
    } catch (error) {
      if (!isUniqueViolation(error)) rethrow;
      await client
          .from(table)
          .update(payload)
          .eq(ownerColumn, ownerId)
          .eq('media_role', role);
    }
  }

  static Future<
    ({Uint8List bytes, String mediaType, String contentType, String fileName})
  >
  readValidatedBytes(
    XFile file, {
    required int maxBytes,
    bool imagesOnly = false,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > maxBytes) {
      throw StorageException(
        'Each photo or video must be ${(maxBytes / (1024 * 1024)).round()} MB or smaller.',
      );
    }
    final mediaType = mediaTypeForFile(file, bytes: bytes);
    if (imagesOnly && mediaType == 'video') {
      throw const StorageException(
        'Choose a photo (JPEG, PNG, WebP, GIF, or HEIC). Videos belong in Photos & Videos.',
      );
    }
    if (mediaType == 'image') {
      final jpeg = jpegBytesFromStill(bytes);
      if (jpeg != null) {
        return (
          bytes: jpeg,
          mediaType: 'image',
          contentType: 'image/jpeg',
          fileName: jpegFileName(file.name),
        );
      }
    }
    return (
      bytes: bytes,
      mediaType: mediaType,
      contentType: mimeTypeForFile(file, mediaType),
      fileName: file.name,
    );
  }
}
