import '../config/media_config.dart';
import 'media_storage_service.dart';

/// Resolves a stored community/group image value to a fresh read URL.
///
/// Supports:
/// - storage paths (`userId/community-avatars/...`)
/// - legacy Supabase signed/public object URLs (extracts path and resigns)
/// - other absolute http(s) URLs (returned as-is)
class EntityImageUrl {
  EntityImageUrl._();

  static final _profileMediaObject = RegExp(
    r'/storage/v1/object/(?:sign|public)/profile-media/([^?]+)',
  );

  static bool looksLikeStoragePath(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.startsWith('http')) return false;
    return trimmed.contains('/');
  }

  static String? extractProfileMediaPath(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (looksLikeStoragePath(trimmed)) return trimmed;
    final match = _profileMediaObject.firstMatch(trimmed);
    if (match == null) return null;
    return Uri.decodeComponent(match.group(1)!);
  }

  static Future<String?> resolve({
    String? storagePath,
    String? legacyUrl,
    MediaStorageProvider provider = MediaStorageProvider.supabase,
    Map<String, String>? context,
  }) async {
    final path = (storagePath != null && storagePath.trim().isNotEmpty)
        ? storagePath.trim()
        : extractProfileMediaPath(legacyUrl);

    if (path != null && path.isNotEmpty) {
      try {
        return await MediaStorageService.createReadUrl(
          bucket: MediaBucket.profile,
          path: path,
          provider: provider,
          context: context,
        );
      } catch (_) {
        // Fall through to legacy absolute URL if present.
      }
    }

    final legacy = legacyUrl?.trim();
    if (legacy != null &&
        legacy.isNotEmpty &&
        (legacy.startsWith('http://') || legacy.startsWith('https://'))) {
      return legacy;
    }
    return null;
  }
}
