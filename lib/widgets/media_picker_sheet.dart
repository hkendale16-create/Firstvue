import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/firstvue_theme.dart';

enum MediaPickerMode { photosAndVideos, photosOnly }

Future<List<XFile>?> showMediaPickerSheet(
  BuildContext context, {
  MediaPickerMode mode = MediaPickerMode.photosAndVideos,
}) {
  if (mode == MediaPickerMode.photosOnly) {
    return showImagePickerSheet(context);
  }
  return _showFullMediaPicker(context);
}

Future<List<XFile>?> showImagePickerSheet(BuildContext context) {
  final picker = ImagePicker();
  final fv = context.fv;
  // Media overlays stay intentionally dark for contrast over imagery.
  final sheetBg = context.isDarkTheme
      ? fv.surface
      : const Color(0xFF10151B);
  final titleColor =
      context.isDarkTheme ? fv.primaryText : FirstVuePalette.dark.primaryText;
  final subtitleColor =
      context.isDarkTheme ? fv.secondaryText : FirstVuePalette.dark.secondaryText;
  final labelColor =
      context.isDarkTheme ? fv.primaryText : FirstVuePalette.dark.primaryText;

  return showModalBottomSheet<List<XFile>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CHOOSE A PHOTO',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JPEG, PNG, WebP, GIF, or HEIC — up to 50 MB.',
              style: TextStyle(color: subtitleColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            _PickerButton(
              icon: Icons.photo_library_outlined,
              iconColor: FirstVueColors.gold,
              label: 'Photo from gallery',
              labelColor: labelColor,
              onTap: () async {
                final photo = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 90,
                );
                if (sheetContext.mounted) {
                  Navigator.pop(
                    sheetContext,
                    photo == null ? null : [photo],
                  );
                }
              },
            ),
            _PickerButton(
              icon: Icons.photo_camera_outlined,
              iconColor: FirstVueColors.teal,
              label: 'Take a photo',
              labelColor: labelColor,
              onTap: () async {
                final photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 90,
                );
                if (sheetContext.mounted) {
                  Navigator.pop(
                    sheetContext,
                    photo == null ? null : [photo],
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<List<XFile>?> _showFullMediaPicker(BuildContext context) {
  final picker = ImagePicker();
  final fv = context.fv;
  final sheetBg = context.isDarkTheme
      ? fv.surface
      : const Color(0xFF10151B);
  final titleColor =
      context.isDarkTheme ? fv.primaryText : FirstVuePalette.dark.primaryText;
  final subtitleColor =
      context.isDarkTheme ? fv.secondaryText : FirstVuePalette.dark.secondaryText;
  final labelColor =
      context.isDarkTheme ? fv.primaryText : FirstVuePalette.dark.primaryText;

  return showModalBottomSheet<List<XFile>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ADD PHOTOS OR VIDEOS',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JPEG, PNG, WebP, GIF, HEIC, MP4, MOV, and more — up to 50 MB each.',
              style: TextStyle(color: subtitleColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            _PickerButton(
              icon: Icons.photo_library_outlined,
              iconColor: FirstVueColors.gold,
              label: 'Photos from gallery',
              labelColor: labelColor,
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
              labelColor: labelColor,
              onTap: () async {
                final video =
                    await picker.pickVideo(source: ImageSource.gallery);
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
              iconColor: FirstVueColors.gold,
              label: 'Photos & videos (all types)',
              labelColor: labelColor,
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
  final Color labelColor;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
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
                    style: TextStyle(color: labelColor, fontSize: 15),
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
