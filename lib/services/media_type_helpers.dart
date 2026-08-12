import 'package:image_picker/image_picker.dart';

String mediaTypeForFile(XFile file) {
  final mimeType = file.mimeType?.toLowerCase() ?? '';
  if (mimeType.startsWith('video/')) return 'video';
  if (mimeType.startsWith('image/')) return 'image';
  final extension = file.name.split('.').last.toLowerCase();
  const videoExtensions = {'mp4', 'mov', 'webm', 'avi', 'mkv', '3gp', 'm4v'};
  return videoExtensions.contains(extension) ? 'video' : 'image';
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
