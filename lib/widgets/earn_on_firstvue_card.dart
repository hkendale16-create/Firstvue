import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/earn_on_firstvue_screen.dart';
import '../theme/firstvue_theme.dart';

/// Compact Home/Explore chip into the Earn hub — one row so Tonight stays the hero.
class EarnOnFirstVueCard extends StatelessWidget {
  const EarnOnFirstVueCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            FirstVuePageRoute(builder: (_) => const EarnOnFirstVueScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                FirstVueColors.gold.withValues(alpha: 0.16),
                FirstVueColors.teal.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
              color: FirstVueColors.gold.withValues(alpha: 0.38),
            ),
            boxShadow: FirstVueColors.goldGlow(intensity: 0.28),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FirstVueColors.gold,
                    boxShadow: FirstVueColors.goldGlow(intensity: 0.45),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: FirstVueColors.onGold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earn on FirstVue',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: fv.primaryText,
                            ),
                      ),
                      Text(
                        'VUE Bounties · 85% to you',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: fv.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: FirstVueColors.gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
