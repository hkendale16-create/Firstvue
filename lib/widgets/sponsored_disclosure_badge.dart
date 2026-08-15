import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Visible disclosure for compensated content (VUE Bounty / sponsored).
class SponsoredDisclosureBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const SponsoredDisclosureBadge({
    super.key,
    this.label = 'VUE Bounty',
    this.compact = false,
  });

  const SponsoredDisclosureBadge.sponsoredExperience({super.key})
      : label = 'Sponsored experience',
        compact = false;

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Semantics(
      label: 'Compensated content disclosure: $label',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: FirstVueColors.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: FirstVueColors.gold.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
