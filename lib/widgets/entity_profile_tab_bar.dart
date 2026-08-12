import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Horizontal borderless tab strip used across entity public profiles.
class EntityProfileTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const EntityProfileTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed: () => onSelected(i),
                style: TextButton.styleFrom(
                  foregroundColor: selectedIndex == i
                      ? FirstVueColors.gold
                      : fv.secondaryText,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight:
                        selectedIndex == i ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.6,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Canonical tab sets by entity type (Phase 2 public layouts).
class EntityProfileTabs {
  EntityProfileTabs._();

  static const user = ['POSTS', 'PHOTOS', 'PORTFOLIO', 'GROUPS', 'COMMUNITIES', 'ABOUT'];
  static const restaurant = ['MENU', 'PHOTOS', 'REVIEWS', 'SHOUT-OUTS', 'ABOUT'];
  static const business = ['ABOUT', 'PHOTOS', 'PORTFOLIO', 'REVIEWS', 'FEED'];
  static const professional = [
    'SERVICES',
    'PORTFOLIO',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];
  static const rental = ['PROPERTY', 'PHOTOS', 'AMENITIES', 'INQUIRIES', 'ABOUT'];
  static const group = ['FEED', 'ABOUT', 'MEMBERS', 'MEDIA'];
  static const community = ['FEED', 'GROUPS', 'MEMBERS', 'MEDIA', 'ABOUT'];

  static List<String> forBusinessType(String? businessType) {
    final type = (businessType ?? '').toLowerCase();
    if (type.contains('restaurant') ||
        type.contains('bar') ||
        type.contains('dining') ||
        type.contains('food')) {
      return restaurant;
    }
    return business;
  }
}
