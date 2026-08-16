import 'dart:typed_data';

import '../config/media_config.dart';
import 'media_storage_service.dart';
import 'media_variants.dart';

/// Upload full still + derived variants to Storage.
class MediaVariantUpload {
  final MediaUploadResult full;
  final MediaUploadResult? thumb;
  final MediaUploadResult? feed;
  final MediaUploadResult? avatar64;
  final MediaUploadResult? avatar128;

  const MediaVariantUpload({
    required this.full,
    this.thumb,
    this.feed,
    this.avatar64,
    this.avatar128,
  });

  String get path => full.path;
  MediaStorageProvider get provider => full.provider;
  String? get thumbnailPath => thumb?.path;
}

class MediaVariantUploader {
  MediaVariantUploader._();

  /// Uploads a still with variants, or a raw (video/passthrough) object.
  static Future<MediaVariantUpload> uploadImageOrBytes({
    required MediaBucket bucket,
    required Uint8List bytes,
    required String contentType,
    required String fileName,
    required String mediaType,
    required int index,
    Map<String, String>? context,
    String? subfolder,
    bool includeAvatarSizes = false,
  }) async {
    if (mediaType == 'image') {
      final prepared = MediaVariants.prepare(
        bytes,
        originalName: fileName,
        includeAvatarSizes: includeAvatarSizes,
      );
      if (prepared != null) {
        return uploadPrepared(
          bucket: bucket,
          prepared: prepared,
          index: index,
          context: context,
          subfolder: subfolder,
          includeAvatarSizes: includeAvatarSizes,
        );
      }
    }

    final full = await MediaStorageService.uploadBytes(
      bucket: bucket,
      bytes: bytes,
      contentType: contentType,
      fileName: fileName,
      index: index,
      context: context,
      subfolder: subfolder,
    );
    return MediaVariantUpload(full: full);
  }

  /// Uploads [prepared] full object plus feed/thumb (and optional avatar sizes).
  /// Best-effort for secondary variants — full upload failure still throws.
  static Future<MediaVariantUpload> uploadPrepared({
    required MediaBucket bucket,
    required PreparedImageVariants prepared,
    required int index,
    Map<String, String>? context,
    String? subfolder,
    bool includeAvatarSizes = false,
  }) async {
    final full = await MediaStorageService.uploadBytes(
      bucket: bucket,
      bytes: prepared.fullBytes,
      contentType: prepared.contentType,
      fileName: prepared.fileName,
      index: index,
      context: context,
      subfolder: subfolder,
    );

    Future<MediaUploadResult?> tryVariant(
      MediaVariant variant,
      Uint8List bytes,
    ) async {
      try {
        final variantPath = MediaVariants.pathFor(full.path, variant);
        return await MediaStorageService.uploadBytesAtPath(
          bucket: bucket,
          path: variantPath,
          bytes: bytes,
          contentType: prepared.contentType,
          context: context,
          providerHint: full.provider,
        );
      } catch (_) {
        return null;
      }
    }

    final thumb = await tryVariant(MediaVariant.thumb, prepared.thumbBytes);
    final feed = await tryVariant(MediaVariant.feed, prepared.feedBytes);
    MediaUploadResult? a64;
    MediaUploadResult? a128;
    if (includeAvatarSizes) {
      if (prepared.avatar64Bytes != null) {
        a64 = await tryVariant(MediaVariant.avatar64, prepared.avatar64Bytes!);
      }
      if (prepared.avatar128Bytes != null) {
        a128 =
            await tryVariant(MediaVariant.avatar128, prepared.avatar128Bytes!);
      }
    }

    return MediaVariantUpload(
      full: full,
      thumb: thumb,
      feed: feed,
      avatar64: a64,
      avatar128: a128,
    );
  }

  /// Prefer a display variant URL; fall back through candidates to full.
  static Future<String> createDisplayUrl({
    required MediaBucket bucket,
    required String storagePath,
    MediaStorageProvider provider = MediaStorageProvider.supabase,
    Map<String, String>? context,
    MediaVariant preferred = MediaVariant.feed,
    String? explicitThumbnailPath,
  }) async {
    // External/demo absolute URLs have no Storage siblings — return as-is.
    if (provider == MediaStorageProvider.external ||
        MediaVariants.isRemoteUrl(storagePath)) {
      return MediaStorageService.createReadUrl(
        bucket: bucket,
        path: storagePath,
        provider: provider,
        context: context,
      );
    }

    final candidates = MediaVariants.candidatePaths(
      storagePath,
      preferred: preferred,
      explicitThumbnailPath: explicitThumbnailPath,
    );
    for (final path in candidates) {
      final url = await MediaStorageService.createReadUrl(
        bucket: bucket,
        path: path,
        provider: provider,
        context: context,
      );
      if (url.trim().isNotEmpty) return url;
    }
    return '';
  }

  /// Best-effort delete of a full object and its derived variant siblings.
  static Future<void> deleteWithVariants({
    required MediaBucket bucket,
    required String storagePath,
    MediaStorageProvider provider = MediaStorageProvider.supabase,
    Map<String, String>? context,
    String? explicitThumbnailPath,
  }) async {
    final paths = <String>{
      storagePath.trim(),
      if ((explicitThumbnailPath ?? '').trim().isNotEmpty)
        explicitThumbnailPath!.trim(),
      MediaVariants.pathFor(storagePath, MediaVariant.thumb),
      MediaVariants.pathFor(storagePath, MediaVariant.feed),
      MediaVariants.pathFor(storagePath, MediaVariant.avatar64),
      MediaVariants.pathFor(storagePath, MediaVariant.avatar128),
    }..removeWhere((p) => p.isEmpty);

    for (final path in paths) {
      try {
        await MediaStorageService.deleteObject(
          bucket: bucket,
          path: path,
          provider: provider,
          context: context,
        );
      } catch (_) {}
    }
  }
}
