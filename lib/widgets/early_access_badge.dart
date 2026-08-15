import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Small Early Access chip. When [onTap] is set, opens the feedback path.
class EarlyAccessBadge extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const EarlyAccessBadge({super.key, this.compact = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FirstVueColors.gold.withValues(alpha: 0.45)),
        color: FirstVueColors.gold.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EARLY ACCESS',
            style: TextStyle(
              color: fv.secondaryText,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chat_bubble_outline,
              size: compact ? 10 : 11,
              color: FirstVueColors.gold.withValues(alpha: 0.85),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;

    return Tooltip(
      message: 'Send feedback',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: chip,
        ),
      ),
    );
  }
}
