import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Small non-intrusive Early Access chip.
class EarlyAccessBadge extends StatelessWidget {
  final bool compact;

  const EarlyAccessBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: FirstVueColors.gold.withValues(alpha: 0.45)),
        color: FirstVueColors.gold.withValues(alpha: 0.08),
      ),
      child: Text(
        'EARLY ACCESS',
        style: TextStyle(
          color: fv.secondaryText,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
