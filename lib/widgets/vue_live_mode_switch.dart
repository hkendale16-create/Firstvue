import 'package:flutter/material.dart';

import '../services/live_mode_preference.dart';
import '../theme/firstvue_theme.dart';

/// Compact borderless VUE | ● LIVE selector (Phase 1).
class VueLiveModeSwitch extends StatelessWidget {
  final FirstVueExperienceMode mode;
  final ValueChanged<FirstVueExperienceMode> onChanged;

  const VueLiveModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final live = mode == FirstVueExperienceMode.live;

    return Semantics(
      label: live ? 'LIVE mode selected' : 'VUE mode selected',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeLabel(
            label: 'VUE',
            selected: !live,
            selectedColor: FirstVueColors.gold,
            unselectedColor: fv.tertiaryText,
            onTap: () => onChanged(FirstVueExperienceMode.vue),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '|',
              style: TextStyle(
                color: fv.tertiaryText.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w300,
                height: 1,
              ),
            ),
          ),
          _ModeLabel(
            label: 'LIVE',
            selected: live,
            selectedColor: FirstVueColors.coral,
            unselectedColor: fv.tertiaryText,
            showLiveDot: true,
            onTap: () => onChanged(FirstVueExperienceMode.live),
          ),
        ],
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final bool showLiveDot;
  final VoidCallback onTap;

  const _ModeLabel({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
    this.showLiveDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLiveDot) ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1.1,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
