import 'package:flutter/material.dart';

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
    final type = (businessType ?? '').toLowerCase();
    if (type.contains('restaurant') ||
        type.contains('food') ||
        type.contains('dining') ||
        type.contains('cafe') ||
        type.contains('bakery') ||
        type.contains('cater')) {
      return restaurant;
    }
    if (type.contains('bar') ||
        type.contains('lounge') ||
        type.contains('nightlife') ||
        type.contains('club') ||
        type.contains('brewery')) {
      return bar;
    }
    if (type.contains('activity') ||
        type.contains('attraction') ||
        type.contains('recreation') ||
        type.contains('entertainment') ||
        type.contains('experience') ||
        type.contains('things to do')) {
      return activity;
    }
    if (type.contains('barber') ||
        type.contains('beauty') ||
        type.contains('salon') ||
        type.contains('spa')) {
      return beauty;
    }
    if (type.contains('event')) {
      return event;
    }
    if (type.contains('rental')) {
      return rental;
    }
    return business;
  }
}
