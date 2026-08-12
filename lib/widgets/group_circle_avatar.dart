import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// True circular group/community profile image with optional ring.
class GroupCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final IconData fallbackIcon;
  final Color? ringColor;
  final VoidCallback? onTap;

  const GroupCircleAvatar({
    super.key,
    required this.imageUrl,
    this.size = 68,
    this.fallbackIcon = Icons.groups_rounded,
    this.ringColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final ring = ringColor ?? fv.borderSubtle;

    Widget avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            ring.withValues(alpha: .95),
            ring.withValues(alpha: .35),
          ],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          // Keep media plate dark for contrast on both themes.
          color: Color(0xFF080B0F),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: SizedBox(
            width: size - 9,
            height: size - 9,
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: size - 9,
                    height: size - 9,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: fv.elevatedSurface,
                      child: Icon(
                        fallbackIcon,
                        color: FirstVueColors.teal,
                        size: size * 0.35,
                      ),
                    ),
                  )
                : ColoredBox(
                    color: fv.elevatedSurface,
                    child: Icon(
                      fallbackIcon,
                      color: FirstVueColors.teal,
                      size: size * 0.35,
                    ),
                  ),
          ),
        ),
      ),
    );

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}

/// Label under a circular group/community avatar for Home rows.
class GroupCircleTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final VoidCallback onTap;
  final Color? ringColor;
  final bool isCreate;
  final double width;

  const GroupCircleTile({
    super.key,
    required this.label,
    required this.imageUrl,
    required this.onTap,
    this.ringColor,
    this.isCreate = false,
    this.width = 78,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Column(
          children: [
            if (isCreate)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: FirstVueColors.coral, width: 2),
                  color: fv.elevatedSurface,
                ),
                child: const Icon(Icons.add, color: FirstVueColors.coral),
              )
            else
              GroupCircleAvatar(
                imageUrl: imageUrl,
                ringColor: ringColor,
              ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fv.primaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
