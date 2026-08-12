import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Cover + profile photo controls for business and professional edit screens.
class EntityProfileMediaEditor extends StatelessWidget {
  final String? avatarUrl;
  final String? coverUrl;
  final bool updating;
  final IconData placeholderIcon;
  final VoidCallback? onChangeCover;
  final VoidCallback? onChangeAvatar;
  final VoidCallback? onRemoveCover;
  final VoidCallback? onRemoveAvatar;

  const EntityProfileMediaEditor({
    super.key,
    this.avatarUrl,
    this.coverUrl,
    this.updating = false,
    this.placeholderIcon = Icons.storefront_outlined,
    this.onChangeCover,
    this.onChangeAvatar,
    this.onRemoveCover,
    this.onRemoveAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROFILE PHOTOS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap cover or profile photo to upload — replace anytime.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .45),
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
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
              gradient: coverUrl == null
                  ? const LinearGradient(
                      colors: [Color(0xFF1A2530), Color(0xFF78B9BE)],
                    )
                  : null,
              image: coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(coverUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (coverUrl != null && onRemoveCover != null)
                    TextButton(
                      onPressed: updating ? null : onRemoveCover,
                      child: const Text('Remove'),
                    ),
                  TextButton.icon(
                    onPressed: updating ? null : onChangeCover,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(coverUrl == null ? 'Cover photo' : 'Replace cover'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: updating ? null : onChangeAvatar,
              child: CircleAvatar(
                key: ValueKey('entity-avatar-${avatarUrl ?? 'empty'}'),
                radius: 40,
                backgroundColor: const Color(0xFF241D22),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Icon(placeholderIcon, color: FirstVueColors.teal, size: 34)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: updating ? null : onChangeAvatar,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(
                      updating
                          ? 'Uploading…'
                          : (avatarUrl == null
                              ? 'Profile photo'
                              : 'Replace photo'),
                    ),
                  ),
                  if (avatarUrl != null && onRemoveAvatar != null) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: updating ? null : onRemoveAvatar,
                      child: const Text('Remove profile photo'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (updating) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(color: FirstVueColors.gold),
        ],
      ],
    );
  }
}
