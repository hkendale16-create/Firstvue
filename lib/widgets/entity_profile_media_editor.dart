import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Cover + profile photo controls for business and professional edit screens.
///
/// Supports change (not upload-only): parents should open a change/view/remove
/// sheet from [onChangeCover] / [onChangeAvatar].
class EntityProfileMediaEditor extends StatelessWidget {
  final String? avatarUrl;
  final String? coverUrl;
  final bool updating;
  final bool avatarIsVideo;
  final IconData placeholderIcon;
  final VoidCallback? onChangeCover;
  final VoidCallback? onChangeAvatar;

  const EntityProfileMediaEditor({
    super.key,
    this.avatarUrl,
    this.coverUrl,
    this.updating = false,
    this.avatarIsVideo = false,
    this.placeholderIcon = Icons.storefront_outlined,
    this.onChangeCover,
    this.onChangeAvatar,
  });

  bool get _hasCover => (coverUrl ?? '').trim().isNotEmpty;
  bool get _hasAvatar => (avatarUrl ?? '').trim().isNotEmpty;

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
          'Tap cover or profile photo to change, view, or remove — not only upload.',
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
              gradient: !_hasCover
                  ? const LinearGradient(
                      colors: [Color(0xFF1A2530), Color(0xFF78B9BE)],
                    )
                  : null,
              image: _hasCover
                  ? DecorationImage(
                      image: NetworkImage(coverUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Align(
              alignment: Alignment.bottomRight,
              child: TextButton.icon(
                onPressed: updating ? null : onChangeCover,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(_hasCover ? 'Change cover' : 'Add cover'),
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
                radius: 40,
                backgroundColor: const Color(0xFF241D22),
                backgroundImage:
                    _hasAvatar && !avatarIsVideo ? NetworkImage(avatarUrl!) : null,
                child: !_hasAvatar
                    ? Icon(placeholderIcon, color: FirstVueColors.teal, size: 34)
                    : (avatarIsVideo
                        ? const Icon(Icons.videocam, color: FirstVueColors.teal)
                        : null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: updating ? null : onChangeAvatar,
                icon: Icon(
                  _hasAvatar
                      ? Icons.photo_camera_outlined
                      : Icons.add_a_photo_outlined,
                  size: 18,
                ),
                label: Text(
                  updating
                      ? 'Updating…'
                      : (_hasAvatar ? 'Change profile photo' : 'Add profile photo'),
                ),
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
