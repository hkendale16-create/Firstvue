import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_type_helpers.dart';

/// Shared helpers for avatar/cover replace flows across entity media tables.
class RoleMediaReplace {
  RoleMediaReplace._();

  static bool isMissingRpc(Object error) {
    return error is PostgrestException && error.code == 'PGRST202';
  }

  static bool isUniqueViolation(Object error) {
    return error is PostgrestException && error.code == '23505';
  }

  static Future<({Uint8List bytes, String mediaType, String contentType})>
      readValidatedBytes(XFile file, {required int maxBytes}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const StorageException('Selected file is empty.');
    }
    if (bytes.length > maxBytes) {
      throw StorageException(
        'Each photo or video must be ${(maxBytes / (1024 * 1024)).round()} MB or smaller.',
      );
    }
    final mediaType = mediaTypeForFile(file);
    final contentType = mimeTypeForFile(file, mediaType);
    return (bytes: bytes, mediaType: mediaType, contentType: contentType);
  }
}
