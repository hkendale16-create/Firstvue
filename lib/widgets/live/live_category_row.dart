import 'package:flutter/material.dart';

import '../../theme/firstvue_theme.dart';
import '../../theme/live_tokens.dart';

enum LiveDiscoveryCategory {
  people,
  events,
  food,
  nightlife,
  businesses,
}

extension LiveDiscoveryCategoryX on LiveDiscoveryCategory {
  String get label => switch (this) {
        LiveDiscoveryCategory.people => 'People',
        LiveDiscoveryCategory.events => 'Events',
        LiveDiscoveryCategory.food => 'Food',
        LiveDiscoveryCategory.nightlife => 'Nightlife',
        LiveDiscoveryCategory.businesses => 'Businesses',
      };

  IconData get icon => switch (this) {
        LiveDiscoveryCategory.people => Icons.people_alt_outlined,
        LiveDiscoveryCategory.events => Icons.confirmation_number_outlined,
        LiveDiscoveryCategory.food => Icons.restaurant_outlined,
        LiveDiscoveryCategory.nightlife => Icons.nightlife_outlined,
        LiveDiscoveryCategory.businesses => Icons.storefront_outlined,
      };
}

class LiveCategoryRow extends StatelessWidget {
  final LiveDiscoveryCategory selected;
  final ValueChanged<LiveDiscoveryCategory> onSelected;

  const LiveCategoryRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: LiveDiscoveryCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = LiveDiscoveryCategory.values[index];
          final active = cat == selected;
          final color = active ? LiveTokens.bronze : context.fv.mutedIcon;
          return InkWell(
            onTap: () => onSelected(cat),
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: active ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active
                              ? LiveTokens.bronze
                              : context.fv.borderSubtle,
                          width: active ? 1.6 : 1,
                        ),
                        color: active
                            ? LiveTokens.bronze.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      child: Icon(cat.icon, size: 20, color: color),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
