import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/firstvue_feedback_sounds.dart';
import '../theme/firstvue_theme.dart';

/// App-wide pull-to-refresh wrapper with FirstVue teal/gold styling.
///
/// Guarded so normal scrolling (especially on mobile web) does not keep
/// firing refresh, flashing the indicator arrow, or blanking the page.
class FirstVueRefreshScaffold extends StatefulWidget {
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
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
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
  State<FirstVueRefreshScaffold> createState() =>
      _FirstVueRefreshScaffoldState();
}

class _FirstVueRefreshScaffoldState extends State<FirstVueRefreshScaffold> {
  static const _minRefreshGap = Duration(seconds: 2);
  static const _refreshTimeout = Duration(seconds: 15);

  bool _refreshing = false;
  DateTime? _lastRefreshAt;

  Future<void> _handleRefresh() async {
    if (_refreshing) return;
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < _minRefreshGap) {
      return;
    }
    _refreshing = true;
    _lastRefreshAt = DateTime.now();
    try {
      await widget.onRefresh().timeout(_refreshTimeout);
    } catch (_) {
      // Never leave the Material indicator spinning on network / audio errors.
    } finally {
      _refreshing = false;
      if (widget.playRefreshSound) {
        // AudioPlayers can hang on mobile web; never block indicator dismiss.
        unawaited(FirstVueFeedbackSounds.playRefresh(intentional: true));
      }
    }
  }

  bool _defaultPredicate(ScrollNotification notification) {
    // Nested scrollables (grids inside lists, mosaic, etc.) must not refresh.
    if (notification.depth != 0) return false;

    // RefreshIndicator needs ScrollEnd to leave armed/drag (show or cancel).
    // Filtering it leaves the reload symbol stuck on screen.
    if (notification is ScrollEndNotification) {
      return true;
    }

    // Ignore bubble-phase noise from layout / dimensions changes.
    if (notification is ScrollMetricsNotification) return false;

    // Only track pull when already pinned to the top — ignore mid-scroll.
    if (notification.metrics.pixels > 0.5) return false;

    return defaultScrollNotificationPredicate(notification);
  }

  @override
  Widget build(BuildContext context) {
    // Mobile web overscroll is twitchy; require a longer pull before refresh.
    final displacement = kIsWeb ? 72.0 : 56.0;
    final edgeOffset = kIsWeb ? 12.0 : 8.0;

    return RefreshIndicator(
      color: FirstVueColors.teal,
      backgroundColor: context.fv.surface,
      displacement: displacement,
      edgeOffset: edgeOffset,
      strokeWidth: kIsWeb ? 3.0 : 2.5,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: _handleRefresh,
      notificationPredicate:
          widget.notificationPredicate ?? _defaultPredicate,
      child: widget.child,
    );
  }
}
