import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Lightweight auto-dismissing status toast. Clears prior toasts so checks
/// never stack permanently on profiles.
class FirstVueEphemeralToast {
  FirstVueEphemeralToast._();

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        backgroundColor: backgroundColor ?? FirstVueColors.elevatedSurface,
        dismissDirection: DismissDirection.down,
      ),
    );
  }
}
