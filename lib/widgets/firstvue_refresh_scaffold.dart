import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/firstvue_feedback_sounds.dart';
import '../theme/firstvue_theme.dart';

/// App-wide pull-to-refresh wrapper with FirstVue teal/gold styling.
///
/// Guarded so normal scrolling (especially on mobile web) does not keep
/// firing refresh, flashing the indicator arrow, or blanking the page.
///
/// Important for Flutter web: [onRefresh] must not complete in 0ms. Instant
/// returns (throttle / already-refreshing) leave the spinner stuck mid-screen.
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
  /// Lets RefreshIndicator finish its show/dismiss animation on mobile web.
  static const _minIndicatorSpin = Duration(milliseconds: 450);

  Future<void>? _inFlight;
  DateTime? _lastRefreshAt;

  Future<void> _handleRefresh() async {
    // Join the in-flight refresh instead of returning instantly (stuck spinner).
    final existing = _inFlight;
    if (existing != null) return existing;

    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last) < _minRefreshGap) {
      await Future<void>.delayed(_minIndicatorSpin);
      return;
    }

    _lastRefreshAt = DateTime.now();
    final started = DateTime.now();
    final run = () async {
      try {
        await widget.onRefresh();
        if (widget.playRefreshSound) {
          await FirstVueFeedbackSounds.playRefresh(intentional: true);
        }
      } finally {
        final elapsed = DateTime.now().difference(started);
        if (elapsed < _minIndicatorSpin) {
          await Future<void>.delayed(_minIndicatorSpin - elapsed);
        }
        _inFlight = null;
      }
    }();
    _inFlight = run;
    await run;
  }

  bool _defaultPredicate(ScrollNotification notification) {
    // Nested scrollables (grids inside lists, mosaic, etc.) must not refresh.
    if (notification.depth != 0) return false;
    // Only when already pinned to the top — ignore mid-scroll rubber-banding.
    if (notification.metrics.pixels > 0.5) return false;
    // Ignore bubble-phase noise from layout / dimensions changes.
    if (notification is ScrollMetricsNotification) return false;
    if (notification is ScrollEndNotification) return false;
    return defaultScrollNotificationPredicate(notification);
  }

  @override
  Widget build(BuildContext context) {
    // Keep displacement modest so the spinner sits under the header
    // instead of floating in the middle of the viewport (esp. mobile web).
    const displacement = 40.0;
    final edgeOffset = kIsWeb ? 8.0 : 0.0;

    return RefreshIndicator(
      color: FirstVueColors.teal,
      backgroundColor: context.fv.surface,
      displacement: displacement,
      edgeOffset: edgeOffset,
      strokeWidth: 2.5,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: _handleRefresh,
      notificationPredicate:
          widget.notificationPredicate ?? _defaultPredicate,
      child: widget.child,
    );
  }
}
