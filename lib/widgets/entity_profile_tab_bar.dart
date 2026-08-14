import 'package:flutter/material.dart';

import '../data/industry_catalog.dart';
import 'social_chrome.dart';

/// Horizontal gold-underline tab strip used across entity public profiles.
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
    return SocialGoldUnderlineTabs(
      labels: labels,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}

/// Canonical tab sets by entity type.
///
/// Every entity profile includes the core Feed / Photos / Reviews /
/// Shout-Outs / About tabs. Type-specific modules are prepended where needed.
class EntityProfileTabs {
  EntityProfileTabs._();

  static const core = ['FEED', 'PHOTOS', 'REVIEWS', 'SHOUT-OUTS', 'ABOUT'];
  static const user = [
    'POSTS',
    'PHOTOS',
    'PORTFOLIO',
    'GROUPS',
    'COMMUNITIES',
    'ABOUT',
  ];
  static const restaurant = [
    'MENU',
    'FEED',
    'PHOTOS',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];
  static const business = [
    'FEED',
    'PHOTOS',
    'PORTFOLIO',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];
  static const professional = [
    'SERVICES',
    'FEED',
    'PHOTOS',
    'PORTFOLIO',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];
  static const rental = [
    'PROPERTY',
    'FEED',
    'PHOTOS',
    'REVIEWS',
    'AMENITIES',
    'ABOUT',
  ];
  static const group = [
    'FEED',
    'PHOTOS',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
    'MEMBERS',
  ];
  static const community = [
    'FEED',
    'PHOTOS',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
    'GROUPS',
  ];
  static const event = ['FEED', 'PHOTOS', 'REVIEWS', 'SHOUT-OUTS', 'ABOUT'];
  static const bar = [
    'DRINKS',
    'FEED',
    'PHOTOS',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];
  static const activity = [
    'EXPERIENCES',
    'FEED',
    'PHOTOS',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];
  static const beauty = [
    'SERVICES',
    'FEED',
    'PHOTOS',
    'PORTFOLIO',
    'REVIEWS',
    'SHOUT-OUTS',
    'ABOUT',
  ];

  static List<String> forBusinessType(String? businessType) {
    return IndustryCatalog.tabsFor(displayType: businessType);
  }
}
