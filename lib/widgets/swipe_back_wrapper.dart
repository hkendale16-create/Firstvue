import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Detects a horizontal swipe-left gesture to pop the current route.
///
/// On mobile, only the right screen edge is sensitive so nested horizontal
/// lists (e.g. media strips) keep working. On web/desktop the full screen
/// accepts swipe-left back because edge swipes are unreliable there.
class SwipeBackWrapper extends StatefulWidget {
  const SwipeBackWrapper({super.key, required this.child});

  final Widget child;

  static const edgeWidth = 24.0;
  static const popThreshold = 80.0;

  static bool get allowFullScreenSwipeBack {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper> {
  bool _tracking = false;
  double _dragTotal = 0;

  void _onDragStart(DragStartDetails details) {
    if (!SwipeBackWrapper.allowFullScreenSwipeBack) {
      final width = MediaQuery.sizeOf(context).width;
      if (details.globalPosition.dx < width - SwipeBackWrapper.edgeWidth) {
        return;
      }
    }
    _tracking = true;
    _dragTotal = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_tracking) return;
    _dragTotal += details.primaryDelta ?? 0;
    if (_dragTotal <= -SwipeBackWrapper.popThreshold) {
      _tracking = false;
      Navigator.maybePop(context);
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_tracking) return;
    if (_dragTotal <= -SwipeBackWrapper.popThreshold) {
      Navigator.maybePop(context);
    }
    _tracking = false;
    _dragTotal = 0;
  }

  void _onDragCancel() {
    _tracking = false;
    _dragTotal = 0;
  }

  Widget _detector({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (SwipeBackWrapper.allowFullScreenSwipeBack) {
      return _detector(child: widget.child);
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: SwipeBackWrapper.edgeWidth,
          child: _detector(child: const SizedBox.expand()),
        ),
      ],
    );
  }
}
