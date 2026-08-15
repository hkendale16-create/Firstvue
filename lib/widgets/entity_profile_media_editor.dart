import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import 'network_photo.dart';

/// Returns `change`, `view`, `remove`, or null if dismissed.
Future<String?> showEntityPhotoActionSheet(
  BuildContext context, {
  required String photoLabel,
  required bool hasPhoto,
}) {
  final changeLabel = hasPhoto ? 'Change $photoLabel' : 'Add $photoLabel';
  return showModalBottomSheet<String>(
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
              Icons.photo_library_outlined,
              color: FirstVueColors.gold,
            ),
            title: Text(
              changeLabel,
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.pop(ctx, 'change'),
          ),
          if (hasPhoto) ...[
            ListTile(
              leading: const Icon(
                Icons.visibility_outlined,
                color: FirstVueColors.teal,
              ),
              title: Text(
                'View $photoLabel',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(ctx, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.white54),
              title: Text(
                'Remove $photoLabel',
                style: const TextStyle(color: Colors.white70),
              ),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Cover + profile photo controls for business and professional edit screens.
class EntityProfileMediaEditor extends StatelessWidget {
  final String? avatarUrl;
  final String? coverUrl;
  final bool updating;
  final IconData placeholderIcon;
  final VoidCallback? onChangeCover;
  final VoidCallback? onChangeAvatar;
  final VoidCallback? onRemoveAvatar;
  final VoidCallback? onRemoveCover;
  final String avatarLabel;
  final String coverLabel;

  const EntityProfileMediaEditor({
    super.key,
    this.avatarUrl,
    this.coverUrl,
    this.updating = false,
    this.placeholderIcon = Icons.storefront_outlined,
    this.onChangeCover,
    this.onChangeAvatar,
    this.onRemoveAvatar,
    this.onRemoveCover,
    this.avatarLabel = 'Profile photo',
    this.coverLabel = 'Cover photo',
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final showRemoveCover =
        onRemoveCover != null && coverUrl != null && coverUrl!.isNotEmpty;
    final showRemoveAvatar =
        onRemoveAvatar != null && avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    final hasCover = coverUrl != null && coverUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROFILE PHOTOS',
          style: TextStyle(
            color: fv.primaryText,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add, change, or remove cover and profile photos for this entity.',
          style: TextStyle(
            color: fv.tertiaryText,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: updating ? null : onChangeCover,
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fv.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  NetworkPhoto(url: coverUrl!, fit: BoxFit.cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          fv.elevatedSurface,
                          FirstVueColors.teal.withValues(alpha: .55),
                        ],
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
                    onPressed: updating ? null : onChangeCover,
                    icon: Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: fv.primaryText,
                    ),
                    label: Text(
                      hasCover ? coverLabel : 'Add $coverLabel',
                      style: TextStyle(color: fv.primaryText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showRemoveCover) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: updating ? null : onRemoveCover,
              child: Text(
                'Remove cover',
                style: TextStyle(color: fv.secondaryText),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: updating ? null : onChangeAvatar,
              child: NetworkCircleAvatar(
                imageUrl: hasAvatar ? avatarUrl : null,
                radius: 40,
                backgroundColor: fv.elevatedSurface,
                placeholder: Icon(
                  placeholderIcon,
                  color: FirstVueColors.teal,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: updating ? null : onChangeAvatar,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(
                  updating
                      ? 'Uploading…'
                      : (hasAvatar ? avatarLabel : 'Add $avatarLabel'),
                ),
              ),
            ),
          ],
        ),
        if (showRemoveAvatar) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: updating ? null : onRemoveAvatar,
              child: Text(
                'Remove profile photo',
                style: TextStyle(color: fv.secondaryText),
              ),
            ),
          ),
        ],
        if (updating) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(color: FirstVueColors.gold),
        ],
      ],
    );
  }
}
