import 'dart:async';

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/post_impressions_service.dart';

/// Fires [PostImpressionsService.recordVisibleImpression] only after the child
/// stays mostly visible (>= 0.6) for ~700ms. Does not fire on mere list load.
class FeedImpressionTracker extends StatefulWidget {
  final String postId;
  final String feedSource;
  final Widget child;
  final Duration dwellDuration;
  final double visibilityThreshold;

  const FeedImpressionTracker({
    super.key,
    required this.postId,
    required this.child,
    this.feedSource = 'main',
    this.dwellDuration = const Duration(milliseconds: 700),
    this.visibilityThreshold = 0.6,
  });

  @override
  State<FeedImpressionTracker> createState() => _FeedImpressionTrackerState();
}

class _FeedImpressionTrackerState extends State<FeedImpressionTracker> {
  Timer? _dwellTimer;
  bool _recorded = false;
  bool _isVisibleEnough = false;
  DateTime? _visibleSince;

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId ||
        oldWidget.feedSource != widget.feedSource) {
      _dwellTimer?.cancel();
      _recorded = false;
      _isVisibleEnough = false;
      _visibleSince = null;
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final enough = info.visibleFraction >= widget.visibilityThreshold;
    if (enough == _isVisibleEnough) return;
    _isVisibleEnough = enough;

    if (!enough) {
      _dwellTimer?.cancel();
      _dwellTimer = null;
      _visibleSince = null;
      return;
    }

    if (_recorded) return;

    _visibleSince = DateTime.now();
    _dwellTimer?.cancel();
    _dwellTimer = Timer(widget.dwellDuration, () {
      if (!mounted || !_isVisibleEnough || _recorded) return;
      final since = _visibleSince;
      if (since == null) return;
      final elapsed = DateTime.now().difference(since);
      if (elapsed < widget.dwellDuration) return;

      _recorded = true;
      PostImpressionsService.recordVisibleImpression(
        postId: widget.postId,
        feedSource: widget.feedSource,
        viewDurationMs: elapsed.inMilliseconds,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('impression-${widget.feedSource}-${widget.postId}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: widget.child,
    );
  }
}
