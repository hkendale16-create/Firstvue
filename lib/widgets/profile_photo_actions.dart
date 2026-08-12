import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'media_picker_sheet.dart';
import 'signed_media_viewer.dart';

enum ProfilePhotoAction { change, view, remove }

/// Bottom sheet used on all FirstVue profiles for avatar/cover changes.
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
  bool allowVideo = true,
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
