import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/firstvue_theme.dart';

/// Feed video that autoplays muted when mostly on screen (~4s preview), then pauses.
class FeedAutoplayVideo extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Duration previewDuration;
  final VoidCallback? onTap;

  const FeedAutoplayVideo({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.previewDuration = const Duration(seconds: 4),
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
  Timer? _previewTimer;
  bool _isMostlyVisible = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant FeedAutoplayVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _previewFinished = false;
      _playing = false;
      _initController();
    }
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() => _ready = true);
      if (_isMostlyVisible) {
        _startPreview();
      }
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _failed = true);
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final mostlyVisible = info.visibleFraction >= 0.55;
    if (mostlyVisible == _isMostlyVisible) return;
    _isMostlyVisible = mostlyVisible;

    if (mostlyVisible) {
      _previewFinished = false;
      _startPreview();
    } else {
      _stopPreview(reset: true);
    }
  }

  void _startPreview() {
    final controller = _controller;
    if (!_ready || controller == null || _failed) return;

    _previewTimer?.cancel();
    controller.seekTo(Duration.zero);
    controller.play();
    setState(() {
      _playing = true;
      _previewFinished = false;
    });

    _previewTimer = Timer(widget.previewDuration, () {
      if (!mounted || !_isMostlyVisible) return;
      controller.pause();
      setState(() {
        _playing = false;
        _previewFinished = true;
      });
    });
  }

  void _stopPreview({required bool reset}) {
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

  void _disposeController() {
    _previewTimer?.cancel();
    _controller?.dispose();
    _controller = null;
    _ready = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTap: widget.onTap,
      child: _buildContent(),
    );

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    if (widget.width != null || widget.height != null) {
      child = SizedBox(width: widget.width, height: widget.height, child: child);
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
          child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 36),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return ColoredBox(
        color: FirstVueColors.elevatedSurface,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FirstVueColors.teal,
            ),
          ),
        ),
      );
    }

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
        if (!_playing || _previewFinished)
          Container(
            color: Colors.black.withValues(alpha: _previewFinished ? 0.25 : 0.15),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _previewFinished ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        if (_playing && !_previewFinished)
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
