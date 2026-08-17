import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Compact mobile-friendly jump control for profile sections.
class ProfileSectionItem {
  final String id;
  final String label;

  const ProfileSectionItem({required this.id, required this.label});
}

class ProfileSectionNav extends StatelessWidget {
  final List<ProfileSectionItem> sections;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String title;

  const ProfileSectionNav({
    super.key,
    required this.sections,
    required this.onSelected,
    this.selectedId,
    this.title = 'Sections',
  });

  @override
  Widget build(BuildContext context) {
    if (sections.length < 2) return const SizedBox.shrink();
    final fv = context.fv;
    final selected = sections.firstWhere(
      (s) => s.id == selectedId,
      orElse: () => sections.first,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        child: PopupMenuButton<String>(
          onSelected: onSelected,
          offset: const Offset(0, 44),
          color: fv.elevatedSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: fv.borderSubtle),
          ),
          itemBuilder: (context) => [
            for (final section in sections)
              PopupMenuItem<String>(
                value: section.id,
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: section.id == selected.id
                        ? FirstVueColors.warmGold
                        : fv.primaryText,
                    fontWeight: section.id == selected.id
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  Icons.view_list_outlined,
                  size: 18,
                  color: FirstVueColors.warmGold.withValues(alpha: .9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title · ${selected.label}',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Icon(Icons.expand_more, color: fv.secondaryText, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
