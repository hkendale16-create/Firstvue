import 'package:image_picker/image_picker.dart';

String mediaTypeForFile(XFile file, {List<int>? bytes}) {
  final fromBytes = mediaTypeFromBytes(bytes);
  if (fromBytes != null) return fromBytes;
  final mimeType = file.mimeType?.toLowerCase() ?? '';
  if (mimeType.startsWith('video/')) return 'video';
  if (mimeType.startsWith('image/')) return 'image';
  final extension = file.name.split('.').last.toLowerCase();
  const videoExtensions = {'mp4', 'mov', 'webm', 'avi', 'mkv', '3gp', 'm4v'};
  return videoExtensions.contains(extension) ? 'video' : 'image';
}

/// Sniff JPEG/PNG vs MP4/MOV when the picker omits a filename or MIME type
/// (common on iOS Safari). Returns null if the header is unknown.
String? mediaTypeFromBytes(List<int>? bytes) {
  if (bytes == null || bytes.length < 12) return null;
  final b = bytes;

  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image';
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return 'image';
  }
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return 'image';
  if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46) {
    final tag = String.fromCharCodes(b.sublist(8, 12));
    if (tag == 'WEBP') return 'image';
    if (tag == 'AVI ') return 'video';
  }
  if (b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
    return 'video';
  }

  // ISO BMFF / QuickTime: 4-byte size + 'ftyp'
  if (b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
    final brand = String.fromCharCodes(b.sublist(8, 12)).toLowerCase();
    const stillBrands = {
      'heic',
      'heix',
      'heif',
      'hevc',
      'hevx',
      'mif1',
      'msf1',
    };
    if (stillBrands.contains(brand)) return 'image';
    return 'video';
  }

  final n = b.length < 64 ? b.length : 64;
  final head = String.fromCharCodes(b.sublist(0, n));
  if (head.contains('moov') || head.contains('mdat') || head.contains('ftyp')) {
    if (head.contains('heic') || head.contains('mif1')) return 'image';
    return 'video';
  }
  return null;
}

String mediaTypeFromMetadata({
  String? mediaType,
  String? mimeType,
  String? pathOrUrl,
}) {
  final stored = mediaType?.toLowerCase().trim();
  if (stored == 'video' || stored == 'image') return stored!;
  final mime = mimeType?.toLowerCase() ?? '';
  if (mime.startsWith('video/')) return 'video';
  if (mime.startsWith('image/')) return 'image';
  final path = (pathOrUrl ?? '').toLowerCase().split('?').first;
  const videoExt = {
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.avi',
    '.mkv',
    '.3gp',
  };
  const imageExt = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
    '.gif',
    '.bmp',
  };
  for (final e in videoExt) {
    if (path.endsWith(e)) return 'video';
  }
  for (final e in imageExt) {
    if (path.endsWith(e)) return 'image';
  }
  return 'image';
}

bool pathHasKnownImageExtension(String? pathOrUrl) {
  final path = (pathOrUrl ?? '').toLowerCase().split('?').first;
  const imageExt = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
    '.gif',
    '.bmp',
  };
  for (final e in imageExt) {
    if (path.endsWith(e)) return true;
  }
  return false;
}

String mimeTypeForFile(XFile file, String mediaType) {
  final supplied = file.mimeType?.toLowerCase();
  if (supplied != null && supplied.isNotEmpty) {
    final suppliedKind = supplied.startsWith('video/')
        ? 'video'
        : supplied.startsWith('image/')
        ? 'image'
        : null;
    // iOS Safari often labels a movie as image/jpeg. Trust sniffed type.
    if (suppliedKind == null || suppliedKind == mediaType) {
      return supplied;
    }
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
