import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Circular avatar tile used on Home Groups / Communities rows.
class GroupCircleTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final Color ringColor;
  final bool isCreate;
  final VoidCallback onTap;

  const GroupCircleTile({
    super.key,
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.ringColor = Colors.white24,
    this.isCreate = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(60),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCreate ? FirstVueColors.coral : ringColor,
                  width: 2.5,
                ),
                color: FirstVueColors.elevatedSurface,
                image: hasImage && !isCreate
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: isCreate
                  ? const Icon(Icons.add, color: FirstVueColors.coral, size: 28)
                  : (!hasImage
                      ? Icon(
                          Icons.groups_rounded,
                          color: FirstVueColors.teal.withValues(alpha: .9),
                          size: 28,
                        )
                      : null),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .88),
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
