import 'package:image_picker/image_picker.dart';

String mediaTypeForFile(XFile file) {
  final mimeType = file.mimeType?.toLowerCase() ?? '';
  if (mimeType.startsWith('video/')) return 'video';
  if (mimeType.startsWith('image/')) return 'image';
  final extension = file.name.split('.').last.toLowerCase();
  const videoExtensions = {'mp4', 'mov', 'webm', 'avi', 'mkv', '3gp', 'm4v'};
  return videoExtensions.contains(extension) ? 'video' : 'image';
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

String mimeTypeForFile(XFile file, String mediaType) {
  final supplied = file.mimeType?.toLowerCase();
  if (supplied != null && supplied.isNotEmpty) {
    return supplied;
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
