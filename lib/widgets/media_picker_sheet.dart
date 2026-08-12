import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/firstvue_theme.dart';

Future<List<XFile>?> showMediaPickerSheet(BuildContext context) {
  final picker = ImagePicker();
  return showModalBottomSheet<List<XFile>>(
    context: context,
    isScrollControlled: true,
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
            _PickerButton(
              icon: Icons.photo_library_outlined,
              iconColor: FirstVueColors.gold,
              label: 'Photos from gallery',
              onTap: () async {
                final photos = await picker.pickMultiImage(imageQuality: 90);
                if (sheetContext.mounted) {
                  Navigator.pop(sheetContext, photos);
                }
              },
            ),
            _PickerButton(
              icon: Icons.videocam_outlined,
              iconColor: FirstVueColors.teal,
              label: 'Video from gallery',
              onTap: () async {
                final video = await picker.pickVideo(source: ImageSource.gallery);
                if (sheetContext.mounted) {
                  Navigator.pop(
                    sheetContext,
                    video == null ? <XFile>[] : [video],
                  );
                }
              },
            ),
            _PickerButton(
              icon: Icons.perm_media_outlined,
              iconColor: const Color(0xFFE5C16F),
              label: 'Photos & videos (all types)',
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

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
