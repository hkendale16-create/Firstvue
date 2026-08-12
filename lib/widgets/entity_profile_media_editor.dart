import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Cover + profile photo controls for business and professional edit screens.
class EntityProfileMediaEditor extends StatelessWidget {
  final String? avatarUrl;
  final String? coverUrl;
  final bool avatarIsVideo;
  final bool updating;
  final IconData placeholderIcon;
  final VoidCallback? onChangeCover;
  final VoidCallback? onChangeAvatar;

  const EntityProfileMediaEditor({
    super.key,
    this.avatarUrl,
    this.coverUrl,
    this.avatarIsVideo = false,
    this.updating = false,
    this.placeholderIcon = Icons.storefront_outlined,
    this.onChangeCover,
    this.onChangeAvatar,
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
          'Tap cover or profile photo to upload a photo or video.',
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
              child: TextButton.icon(
                onPressed: updating ? null : onChangeCover,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Cover photo'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            GestureDetector(
              onTap: updating ? null : onChangeAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF241D22),
                    backgroundImage: avatarUrl != null && !avatarIsVideo
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? Icon(
                            placeholderIcon,
                            color: FirstVueColors.teal,
                            size: 34,
                          )
                        : avatarIsVideo
                            ? const Icon(
                                Icons.videocam_rounded,
                                color: FirstVueColors.gold,
                                size: 30,
                              )
                            : null,
                  ),
                  if (avatarIsVideo && avatarUrl != null)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF080B0F),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: updating ? null : onChangeAvatar,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(
                  updating ? 'Uploading…' : 'Profile photo / video',
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
