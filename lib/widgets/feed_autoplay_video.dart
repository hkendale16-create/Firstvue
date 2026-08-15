import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/firstvue_theme.dart';

/// Caps how many feed videos may hold a live [VideoPlayerController] at once.
/// iOS Safari repeatedly kills the tab when many CanvasKit video textures stay
/// allocated while scrolling Feeds / Home / VUE.
class _FeedVideoBudget {
  _FeedVideoBudget._();

  static const int maxActiveWeb = 1;
  static const int maxActiveNative = 3;

  static final List<_FeedAutoplayVideoState> _active = [];

  static int get _limit => kIsWeb ? maxActiveWeb : maxActiveNative;

  static void claim(_FeedAutoplayVideoState state) {
    if (_active.contains(state)) return;
    _active.add(state);
    while (_active.length > _limit) {
      final oldest = _active.removeAt(0);
      if (!identical(oldest, state)) {
        oldest._releaseForBudget();
      }
    }
  }

  static void release(_FeedAutoplayVideoState state) {
    _active.remove(state);
  }
}

/// Feed video that autoplays muted when mostly on screen.
///
/// Controllers are created lazily when visible and released when scrolled away
/// (especially on web) so Safari does not OOM mid-scroll.
class FeedAutoplayVideo extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool previewOnly;
  final Duration previewDuration;
  final VoidCallback? onTap;

  const FeedAutoplayVideo({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.previewOnly = false,
    this.previewDuration = const Duration(seconds: 3),
    this.onTap,
  });

  @override
  State<FeedAutoplayVideo> createState() => _FeedAutoplayVideoState();
}

class _FeedAutoplayVideoState extends State<FeedAutoplayVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;
  bool _previewFinished = false;
  bool _initializing = false;
  Timer? _previewTimer;
  Timer? _releaseTimer;
  bool _muted = true;
  bool _isMostlyVisible = false;

  void _toggleMute() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    setState(() => _muted = !_muted);
    controller.setVolume(_muted ? 0 : 1);
  }

  @override
  void didUpdateWidget(covariant FeedAutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController(releaseBudget: true);
      _previewFinished = false;
      _playing = false;
      _failed = false;
      if (_isMostlyVisible) {
        unawaited(_ensureController());
      }
    } else if (oldWidget.previewOnly != widget.previewOnly &&
        _isMostlyVisible) {
      if (widget.previewOnly) {
        _startPlayback();
      } else {
        _previewTimer?.cancel();
        _previewFinished = false;
        _resumeLoop();
      }
    }
  }

  Future<void> _ensureController() async {
    if (_controller != null || _initializing || _failed) return;
    _initializing = true;
    _FeedVideoBudget.claim(this);
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _controller != controller || !_isMostlyVisible) {
        await controller.dispose();
        if (_controller == controller) _controller = null;
        _initializing = false;
        _FeedVideoBudget.release(this);
        return;
      }
      if (mounted) {
        setState(() {
          _ready = true;
          _initializing = false;
        });
      } else {
        _initializing = false;
      }
      if (_isMostlyVisible) {
        _startPlayback();
      }
    } catch (_) {
      if (!mounted || _controller != controller) {
        _initializing = false;
        return;
      }
      setState(() {
        _failed = true;
        _initializing = false;
      });
      _FeedVideoBudget.release(this);
    }
  }

  void _releaseForBudget() {
    if (!mounted) {
      _disposeController(releaseBudget: false);
      return;
    }
    _pausePlayback(reset: true);
    _disposeController(releaseBudget: false);
    if (mounted) setState(() {});
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final mostlyVisible = info.visibleFraction >= 0.55;
    if (mostlyVisible == _isMostlyVisible) return;
    _isMostlyVisible = mostlyVisible;

    if (mostlyVisible) {
      _releaseTimer?.cancel();
      _previewFinished = false;
      unawaited(_ensureController());
      _startPlayback();
    } else {
      _pausePlayback(reset: true);
      // Free decoder/GPU quickly on web; keep briefly on native for fling-back.
      _releaseTimer?.cancel();
      _releaseTimer = Timer(
        Duration(milliseconds: kIsWeb ? 120 : 800),
        () {
          if (!mounted || _isMostlyVisible) return;
          _disposeController(releaseBudget: true);
          if (mounted) setState(() {});
        },
      );
    }
  }

  void _startPlayback() {
    final controller = _controller;
    if (!_ready || controller == null || _failed) return;

    _previewTimer?.cancel();
    if (widget.previewOnly && controller.value.position > Duration.zero) {
      controller.seekTo(Duration.zero);
    }
    controller.play();
    if (mounted) {
      setState(() {
        _playing = true;
        _previewFinished = false;
      });
    }

    if (!widget.previewOnly) return;

    _previewTimer = Timer(widget.previewDuration, () {
      if (!mounted || !_isMostlyVisible) return;
      controller.pause();
      setState(() {
        _playing = false;
        _previewFinished = true;
      });
    });
  }

  void _resumeLoop() {
    final controller = _controller;
    if (!_ready || controller == null || _failed) return;
    controller.play();
    if (mounted) {
      setState(() {
        _playing = true;
        _previewFinished = false;
      });
    }
  }

  void _pausePlayback({required bool reset}) {
    _previewTimer?.cancel();
    final controller = _controller;
    if (controller != null && _ready) {
      controller.pause();
      if (reset) {
        controller.seekTo(Duration.zero);
      }
    }
    if (mounted) {
      setState(() {
        _playing = false;
        if (reset) _previewFinished = false;
      });
    }
  }

  void _disposeController({required bool releaseBudget}) {
    _previewTimer?.cancel();
    _releaseTimer?.cancel();
    final controller = _controller;
    _controller = null;
    _ready = false;
    _initializing = false;
    _playing = false;
    if (releaseBudget) _FeedVideoBudget.release(this);
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController(releaseBudget: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(onTap: widget.onTap, child: _buildContent());

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    if (widget.width != null || widget.height != null) {
      child = SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      );
    }

    return VisibilityDetector(
      key: Key('feed-video-${widget.url.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: child,
    );
  }

  Widget _buildContent() {
    if (_failed) {
      return ColoredBox(
        color: FirstVueColors.elevatedSurface,
        child: const Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: Colors.white38,
            size: 36,
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return ColoredBox(
        color: FirstVueColors.elevatedSurface,
        child: Center(
          child: _initializing || _isMostlyVisible
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FirstVueColors.teal,
                  ),
                )
              : const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white38,
                  size: 40,
                ),
        ),
      );
    }

    final showPausedOverlay = !_playing || _previewFinished;

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
        if (showPausedOverlay)
          Container(
            color: Colors.black.withValues(
              alpha: _previewFinished ? 0.25 : 0.15,
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _previewFinished
                      ? Icons.replay_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        if (_playing && !_previewFinished)
          Positioned(
            right: 8,
            bottom: 8,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _toggleMute,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .55),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        if (widget.previewOnly && _playing && !_previewFinished)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PREVIEW',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
