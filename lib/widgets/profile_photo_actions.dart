import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'media_picker_sheet.dart';
import 'signed_media_viewer.dart';

enum ProfilePhotoAction { change, view, remove }

/// Bottom sheet used on edit screens and profiles for avatar/cover changes.
Future<ProfilePhotoAction?> showProfilePhotoActionSheet(
  BuildContext context, {
  required String changeLabel,
  required String viewLabel,
  required String removeLabel,
  required bool hasExisting,
  bool allowRemove = true,
}) {
  return showModalBottomSheet<ProfilePhotoAction>(
    context: context,
    backgroundColor: const Color(0xFF10151B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: Color(0xFFD8B56A),
            ),
            title: Text(
              changeLabel,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(ctx, ProfilePhotoAction.change),
          ),
          if (hasExisting) ...[
            ListTile(
              leading: const Icon(
                Icons.visibility_outlined,
                color: Color(0xFF78B9BE),
              ),
              title: Text(
                viewLabel,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, ProfilePhotoAction.view),
            ),
            if (allowRemove)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white54),
                title: Text(
                  removeLabel,
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () => Navigator.pop(ctx, ProfilePhotoAction.remove),
              ),
          ],
        ],
      ),
    ),
  );
}

Future<XFile?> pickProfilePhoto(
  BuildContext context, {
  bool allowVideo = false,
}) async {
  final files = await showMediaPickerSheet(
    context,
    mode: allowVideo
        ? MediaPickerMode.photosAndVideos
        : MediaPickerMode.photosOnly,
  );
  if (files == null || files.isEmpty) return null;
  return files.first;
}

Future<void> viewProfilePhoto(
  BuildContext context, {
  required String url,
  required bool isVideo,
  required String title,
}) async {
  openSignedMedia(
    context,
    url: url,
    isVideo: isVideo,
    title: title,
  );
}

/// Shared edit-profile flow: change / view / remove for avatar or cover.
Future<void> runProfilePhotoEditFlow({
  required BuildContext context,
  required String kindLabel,
  required bool hasExisting,
  String? existingUrl,
  bool existingIsVideo = false,
  bool allowVideo = false,
  bool allowRemove = true,
  required Future<void> Function(XFile file) onChange,
  required Future<void> Function() onRemove,
}) async {
  final action = await showProfilePhotoActionSheet(
    context,
    changeLabel: hasExisting ? 'Change $kindLabel' : 'Upload $kindLabel',
    viewLabel: 'View $kindLabel',
    removeLabel: 'Remove $kindLabel',
    hasExisting: hasExisting,
    allowRemove: allowRemove,
  );
  if (!context.mounted || action == null) return;

  if (action == ProfilePhotoAction.view) {
    final url = existingUrl;
    if (url == null || url.isEmpty) return;
    await viewProfilePhoto(
      context,
      url: url,
      isVideo: existingIsVideo,
      title: kindLabel.toUpperCase(),
    );
    return;
  }

  if (action == ProfilePhotoAction.remove) {
    await onRemove();
    return;
  }

  final picked = await pickProfilePhoto(context, allowVideo: allowVideo);
  if (picked == null || !context.mounted) return;
  await onChange(picked);
}

/// Change / remove an already-attached post media file before publishing.
Future<XFile?> runAttachedMediaEditFlow(
  BuildContext context, {
  required XFile current,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF10151B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(
              Icons.photo_camera_outlined,
              color: Color(0xFFD8B56A),
            ),
            title: const Text(
              'Change attachment',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(ctx, 'change'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.white54),
            title: const Text(
              'Remove attachment',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return current;
  if (action == 'remove') return null;
  final picked = await pickProfilePhoto(context, allowVideo: true);
  return picked ?? current;
}
