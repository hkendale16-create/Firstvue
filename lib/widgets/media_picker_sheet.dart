import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/firstvue_theme.dart';

Future<List<XFile>?> showMediaPickerSheet(BuildContext context) {
  final picker = ImagePicker();
  return showModalBottomSheet<List<XFile>>(
    context: context,
    backgroundColor: const Color(0xFF10151B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ADD PHOTOS OR VIDEOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'JPEG, PNG, WebP, GIF, HEIC, MP4, MOV, and more — up to 50 MB each.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: FirstVueColors.gold),
              title: const Text('Photos from gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final photos = await picker.pickMultiImage(imageQuality: 90);
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, photos);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: FirstVueColors.teal),
              title: const Text('Video from gallery', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final video = await picker.pickVideo(source: ImageSource.gallery);
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, video == null ? <XFile>[] : [video]);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.perm_media_outlined, color: Color(0xFFE5C16F)),
              title: const Text(
                'Photos & videos (all types)',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () async {
                final media = await picker.pickMultipleMedia(imageQuality: 90);
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, media);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}
