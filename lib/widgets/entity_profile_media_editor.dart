import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import 'network_photo.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final showRemoveCover =
        onRemoveCover != null && coverUrl != null && coverUrl!.isNotEmpty;
    final showRemoveAvatar =
        onRemoveAvatar != null && avatarUrl != null && avatarUrl!.isNotEmpty;

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
          'Tap cover or profile photo to upload — just like your main profile.',
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
                if (coverUrl != null)
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
                      'Cover photo',
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
                imageUrl: avatarUrl,
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
                label: Text(updating ? 'Uploading…' : 'Profile photo'),
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
