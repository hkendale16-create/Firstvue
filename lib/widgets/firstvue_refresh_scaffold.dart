import 'package:flutter/material.dart';

import '../services/firstvue_feedback_sounds.dart';
import '../theme/firstvue_theme.dart';

/// App-wide pull-to-refresh wrapper with FirstVue teal/gold styling.
///
/// Wrap scrollable content (ListView, CustomScrollView, etc.) or use
/// [alwaysScrollable] for short / empty states that may not scroll on their own.
class FirstVueRefreshScaffold extends StatelessWidget {
  const FirstVueRefreshScaffold({
    super.key,
    required this.onRefresh,
    required this.child,
    this.notificationPredicate,
    this.playRefreshSound = true,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final ScrollNotificationPredicate? notificationPredicate;
  final bool playRefreshSound;

  /// Wraps [child] so [RefreshIndicator] can trigger even when content is short.
  static Widget alwaysScrollable({
    required Widget child,
    EdgeInsetsGeometry? padding,
    ScrollController? controller,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: FirstVueColors.teal,
      backgroundColor: context.fv.surface,
      displacement: 40,
      onRefresh: () async {
        await onRefresh();
        if (playRefreshSound) {
          await FirstVueFeedbackSounds.playRefresh(intentional: true);
        }
      },
      notificationPredicate:
          notificationPredicate ?? defaultScrollNotificationPredicate,
      child: child,
    );
  }
}
