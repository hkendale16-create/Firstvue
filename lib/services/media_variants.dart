import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'media_transcode.dart';

/// Display intent for still images. Full remains the source-of-truth object.
enum MediaVariant {
  /// ~64px — tiny avatars / chrome
  avatar64,

  /// ~128px — list / mosaic avatars
  avatar128,

  /// ~480px — grid / mosaic / cards
  thumb,

  /// ~960px — feed timeline
  feed,

  /// ~1600px — detail / fullscreen stills
  full,
}

/// Path + encode helpers for image variants without requiring schema changes.
///
/// Variant objects live beside the full object:
/// `user/123_photo.jpg` → `user/123_photo__v_thumb.jpg`
class MediaVariants {
  MediaVariants._();

  static const _marker = '__v_';

  static String suffix(MediaVariant variant) => switch (variant) {
        MediaVariant.avatar64 => 'a64',
        MediaVariant.avatar128 => 'a128',
        MediaVariant.thumb => 'thumb',
        MediaVariant.feed => 'feed',
        MediaVariant.full => 'full',
      };

  static int maxEdge(MediaVariant variant) => switch (variant) {
        MediaVariant.avatar64 => 64,
        MediaVariant.avatar128 => 128,
        MediaVariant.thumb => 480,
        MediaVariant.feed => 960,
        MediaVariant.full => 1600,
      };

  static int jpegQuality(MediaVariant variant) => switch (variant) {
        MediaVariant.avatar64 => 82,
        MediaVariant.avatar128 => 85,
        MediaVariant.thumb => 80,
        MediaVariant.feed => 82,
        MediaVariant.full => 85,
      };

  /// Returns a sibling path for [variant], or [storagePath] for [MediaVariant.full].
  static String pathFor(String storagePath, MediaVariant variant) {
    final trimmed = storagePath.trim();
    if (trimmed.isEmpty || variant == MediaVariant.full) return trimmed;
    if (trimmed.contains(_marker)) return trimmed;

    final slash = trimmed.lastIndexOf('/');
    final dir = slash >= 0 ? trimmed.substring(0, slash + 1) : '';
    final file = slash >= 0 ? trimmed.substring(slash + 1) : trimmed;
    final dot = file.lastIndexOf('.');
    final base = dot > 0 ? file.substring(0, dot) : file;
    return '$dir$base$_marker${suffix(variant)}.jpg';
  }

  /// Prefer list/feed display paths before falling back to the full object.
  static List<String> candidatePaths(
    String storagePath, {
    MediaVariant preferred = MediaVariant.feed,
    String? explicitThumbnailPath,
  }) {
    final full = storagePath.trim();
    if (full.isEmpty) return const [];
    final out = <String>[];
    void add(String? path) {
      final p = path?.trim() ?? '';
      if (p.isEmpty || out.contains(p)) return;
      out.add(p);
    }

    add(explicitThumbnailPath);
    if (preferred != MediaVariant.full) {
      add(pathFor(full, preferred));
      if (preferred == MediaVariant.feed) {
        add(pathFor(full, MediaVariant.thumb));
      }
    }
    add(full);
    return out;
  }

  /// Encode [bytes] into the requested still variants. Returns null if not a
  /// decodable still image (video / HEIC passthrough cases).
  static PreparedImageVariants? prepare(
    List<int> bytes, {
    required String originalName,
    bool includeAvatarSizes = false,
  }) {
    if (bytes.length < 12) return null;
    try {
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return null;

      Uint8List encode(MediaVariant variant) {
        final edge = maxEdge(variant);
        var image = decoded;
        if (image.width > edge || image.height > edge) {
          if (image.width >= image.height) {
            image = img.copyResize(
              image,
              width: edge,
              interpolation: img.Interpolation.linear,
            );
          } else {
            image = img.copyResize(
              image,
              height: edge,
              interpolation: img.Interpolation.linear,
            );
          }
        }
        return Uint8List.fromList(
          img.encodeJpg(image, quality: jpegQuality(variant)),
        );
      }

      final full = encode(MediaVariant.full);
      final thumb = encode(MediaVariant.thumb);
      final feed = encode(MediaVariant.feed);
      return PreparedImageVariants(
        fullBytes: full,
        thumbBytes: thumb,
        feedBytes: feed,
        avatar64Bytes:
            includeAvatarSizes ? encode(MediaVariant.avatar64) : null,
        avatar128Bytes:
            includeAvatarSizes ? encode(MediaVariant.avatar128) : null,
        fileName: jpegFileName(originalName),
        contentType: 'image/jpeg',
      );
    } catch (_) {
      return null;
    }
  }
}

class PreparedImageVariants {
  final Uint8List fullBytes;
  final Uint8List thumbBytes;
  final Uint8List feedBytes;
  final Uint8List? avatar64Bytes;
  final Uint8List? avatar128Bytes;
  final String fileName;
  final String contentType;

  const PreparedImageVariants({
    required this.fullBytes,
    required this.thumbBytes,
    required this.feedBytes,
    this.avatar64Bytes,
    this.avatar128Bytes,
    required this.fileName,
    required this.contentType,
  });
}
