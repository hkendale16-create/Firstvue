import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

class FirstVueBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FirstVueBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _vueIndex = 2;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
              color: FirstVueColors.background.withValues(alpha: .96),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: .06)),
              ),
            ),
            child: Row(
              children: [
                _NavItem(
                  label: 'HOME',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  selected: selectedIndex == 0,
                  selectedColor: FirstVueColors.gold,
                  onTap: () => onSelected(0),
                ),
                _NavItem(
                  label: 'NOW',
                  icon: Icons.bolt_outlined,
                  selectedIcon: Icons.bolt_rounded,
                  selected: selectedIndex == 1,
                  selectedColor: FirstVueColors.teal,
                  onTap: () => onSelected(1),
                ),
                const Expanded(child: SizedBox(width: 72)),
                _NavItem(
                  label: 'FAVORITES',
                  icon: Icons.bookmark_border_rounded,
                  selectedIcon: Icons.bookmark_rounded,
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
            bottom: 22 + bottomInset,
            child: _VueCenterTab(
              selected: selectedIndex == _vueIndex,
              onTap: () => onSelected(_vueIndex),
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
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : FirstVueColors.mutedIcon;

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FirstVueColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? FirstVueColors.coral
                      : FirstVueColors.coral.withValues(alpha: .55),
                  width: selected ? 2 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: FirstVueColors.coral.withValues(
                      alpha: selected ? .45 : .28,
                    ),
                    blurRadius: selected ? 18 : 12,
                    spreadRadius: selected ? 1 : 0,
                  ),
                ],
              ),
              child: Text(
                'V',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: FirstVueColors.gold,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: FirstVueColors.coral.withValues(alpha: .35),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'VUE',
              style: TextStyle(
                color: selected ? FirstVueColors.gold : FirstVueColors.mutedIcon,
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
