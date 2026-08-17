import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Shared permanent-deletion confirmation for entity profiles.
///
/// Returns `true` only when the user confirms. Personal account deletion must
/// continue to use the dedicated Privacy / account-deletion flow.
Future<bool> confirmDeleteEntity(
  BuildContext context, {
  required String entityLabel,
  String? detail,
}) async {
  final fv = context.fv;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: fv.elevatedSurface,
        title: Text(
          'Delete $entityLabel forever?',
          style: TextStyle(color: fv.primaryText, fontWeight: FontWeight.w700),
        ),
        content: Text(
          detail ??
              'This permanently deletes this $entityLabel and related posts, '
                  'media, memberships, followers, and location data. '
                  'This cannot be undone.\n\n'
                  'This does not delete your personal FirstVue account.',
          style: TextStyle(color: fv.secondaryText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: fv.secondaryText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB33A3A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete forever'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
