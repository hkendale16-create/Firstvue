import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import 'tutorial_targets.dart';

class FirstVueBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FirstVueBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const homeIndex = 0;
  static const feedsIndex = 1;
  static const vueIndex = 2;
  static const exploreIndex = 3;
  static const profileIndex = 4;

  /// Bottom-nav index for an authenticated route. Null means keep the landing
  /// tab and push a stacked destination (Settings, messages, a deep link).
  static int? indexForRoute(String? routeName) {
    final path = Uri.tryParse(routeName ?? '')?.path ?? routeName ?? '';
    return switch (path) {
      '/' || '' || '/vue' => vueIndex,
      '/feeds' => feedsIndex,
      '/explore' => exploreIndex,
      '/profile' => profileIndex,
      '/home' => homeIndex,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final fv = context.fv;

    return SizedBox(
      height: 78 + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 68 + bottomInset,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: fv.navBar.withValues(alpha: .96),
              border: Border(
                top: BorderSide(color: fv.divider),
              ),
            ),
            child: Row(
              children: [
                _NavItem(
                  key: TutorialTargets.homeNav,
                  label: 'HOME',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  selected: selectedIndex == 0,
                  selectedColor: FirstVueColors.gold,
                  onTap: () => onSelected(0),
                ),
                _NavItem(
                  key: TutorialTargets.feedsNav,
                  label: 'FEEDS',
                  icon: Icons.dynamic_feed_outlined,
                  selectedIcon: Icons.dynamic_feed_rounded,
                  selected: selectedIndex == 1,
                  selectedColor: FirstVueColors.teal,
                  onTap: () => onSelected(1),
                ),
                const Expanded(child: SizedBox(width: 72)),
                _NavItem(
                  key: TutorialTargets.exploreNav,
                  label: 'EXPLORE',
                  icon: Icons.search,
                  selectedIcon: Icons.search,
                  selected: selectedIndex == 3,
                  selectedColor: FirstVueColors.gold,
                  onTap: () => onSelected(3),
                ),
                _NavItem(
                  label: 'PROFILE',
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  selected: selectedIndex == 4,
                  selectedColor: FirstVueColors.gold,
                  onTap: () => onSelected(4),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 18 + bottomInset,
            child: KeyedSubtree(
              key: TutorialTargets.vueNav,
              child: _VueCenterTab(
                selected: selectedIndex == vueIndex,
                onTap: () => onSelected(vueIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : context.fv.mutedIcon;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VueCenterTab extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _VueCenterTab({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FirstVueColors.gold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: FirstVueColors.gold.withValues(
                      alpha: selected ? .42 : .28,
                    ),
                    blurRadius: selected ? 16 : 12,
                    spreadRadius: selected ? 1 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'V',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'VUE',
              style: TextStyle(
                color: selected ? FirstVueColors.gold : fv.mutedIcon,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
