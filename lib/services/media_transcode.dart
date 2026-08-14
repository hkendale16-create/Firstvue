import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _maxEdge = 1600;

/// Re-encode a still image as a browser-friendly JPEG (max 1600px).
/// Returns null when the bytes are not a decodable still (HEIC, video, etc.).
Uint8List? jpegBytesFromStill(List<int> bytes) {
  if (bytes.length < 12) return null;
  try {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return null;
    var image = decoded;
    if (image.width > _maxEdge || image.height > _maxEdge) {
      if (image.width >= image.height) {
        image = img.copyResize(
          image,
          width: _maxEdge,
          interpolation: img.Interpolation.linear,
        );
      } else {
        image = img.copyResize(
          image,
          height: _maxEdge,
          interpolation: img.Interpolation.linear,
        );
      }
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 85));
  } catch (_) {
    return null;
  }
}

String jpegFileName(String originalName) {
  final raw = originalName.split('/').last.trim();
  final dot = raw.lastIndexOf('.');
  final base = dot > 0 ? raw.substring(0, dot) : raw;
  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return '${safe.isEmpty ? 'photo' : safe}.jpg';
}
