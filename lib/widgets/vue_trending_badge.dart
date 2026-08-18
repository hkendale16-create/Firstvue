import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Small 🔥 rank chip that stays readable on light and dark media.
class VueTrendingBadge extends StatelessWidget {
  final int rank;
  final bool compact;

  const VueTrendingBadge({
    super.key,
    required this.rank,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (rank <= 0) return const SizedBox.shrink();
    final label = compact ? '#$rank' : '🔥 #$rank Trending';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC0B1020),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: FirstVueColors.gold.withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 3 : 4,
        ),
        child: Text(
          label,
          key: Key('vue-trending-badge-$rank'),
          style: TextStyle(
            color: FirstVueColors.gold,
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1.1,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
