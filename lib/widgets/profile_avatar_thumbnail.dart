import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Compact avatar for lists — uses image URL or initial; video URLs show as image.
class ProfileAvatarThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;

  const ProfileAvatarThumbnail({
    super.key,
    this.imageUrl,
    required this.displayName,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: FirstVueColors.elevatedSurface,
      backgroundImage:
          imageUrl != null && imageUrl!.isNotEmpty && !_looksLikeVideo(imageUrl!)
              ? NetworkImage(imageUrl!)
              : null,
      child: imageUrl == null ||
              imageUrl!.isEmpty ||
              _looksLikeVideo(imageUrl!)
          ? Text(
              initial,
              style: TextStyle(
                color: FirstVueColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.85,
              ),
            )
          : null,
    );
  }

  bool _looksLikeVideo(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('video');
  }
}
