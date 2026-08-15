import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/firstvue_theme.dart';
import '../utils/web_safari_media.dart';
import 'network_photo.dart';

/// Muted Explore-grid video preview with visibility-aware controller lifecycle.
///
/// Plays silently while mostly visible. Reverse (boomerang) playback is not
/// reliably supported by `video_player`, so previews use a seamless forward
/// loop. Controllers are disposed when tiles leave the viewport so Explore does
/// not keep unlimited players alive.
///
/// On Flutter web, previews stay poster-only — Safari OOMs when several
/// CanvasKit video textures stay allocated in the Explore grid.
class ExploreGridVideo extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final VoidCallback? onTap;

  const ExploreGridVideo({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.onTap,
  });

  /// Soft cap on simultaneously initialized Explore video controllers.
  static int get maxActiveControllers => kIsWeb ? 0 : 4;

  static int _activeControllers = 0;
  static final List<VoidCallback> _waitQueue = <VoidCallback>[];

  static bool _tryAcquire() {
    if (_activeControllers >= maxActiveControllers) return false;
    _activeControllers++;
    return true;
  }

  static void _release() {
    if (_activeControllers > 0) _activeControllers--;
    _drainQueue();
  }

  static void _drainQueue() {
    while (_waitQueue.isNotEmpty && _activeControllers < maxActiveControllers) {
      final next = _waitQueue.removeAt(0);
      if (!_tryAcquire()) {
        _waitQueue.insert(0, next);
        return;
      }
      next();
    }
  }

  static void _enqueue(VoidCallback callback) => _waitQueue.add(callback);

  static void _cancelQueued(VoidCallback callback) =>
      _waitQueue.remove(callback);

  @override
  State<ExploreGridVideo> createState() => _ExploreGridVideoState();
}

class _ExploreGridVideoState extends State<ExploreGridVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _loading = false;
  bool _visible = false;
  bool _holdsSlot = false;
  Timer? _hideDisposeTimer;
  Timer? _previewLoopTimer;
  VoidCallback? _queuedAcquire;
  static const _previewLoop = Duration(seconds: 3);

  @override
  void didUpdateWidget(covariant ExploreGridVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _failed = false;
      if (_visible) _requestController();
    }
  }

  @override
  void dispose() {
    _hideDisposeTimer?.cancel();
    _stopPreviewLoop();
    _cancelQueueEntry();
    _disposeController();
    super.dispose();
  }

  void _stopPreviewLoop() {
    _previewLoopTimer?.cancel();
    _previewLoopTimer = null;
  }

  void _startPreviewLoop(VideoPlayerController controller) {
    _stopPreviewLoop();
    _previewLoopTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_visible || !_ready) return;
      final position = controller.value.position;
      if (position >= _previewLoop) {
        controller.seekTo(Duration.zero);
      }
    });
  }

  void _cancelQueueEntry() {
    final queued = _queuedAcquire;
    if (queued == null) return;
    ExploreGridVideo._cancelQueued(queued);
    _queuedAcquire = null;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.35;
    if (visible) {
      _hideDisposeTimer?.cancel();
      _visible = true;
      if (_controller == null && !_loading && !_failed) {
        _requestController();
      } else if (_ready) {
        _controller?.play();
        if (_controller != null) _startPreviewLoop(_controller!);
      }
      return;
    }

    _visible = false;
    _controller?.pause();
    _stopPreviewLoop();
    _hideDisposeTimer?.cancel();
    _hideDisposeTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _visible) return;
      _disposeController();
      if (mounted) setState(() {});
    });
  }

  void _requestController() {
    if (webAvoidInlineVideoPreview) return;
    if (_controller != null || _loading || _failed || _holdsSlot) return;
    if (ExploreGridVideo._tryAcquire()) {
      _holdsSlot = true;
      _initController();
      return;
    }
    _queuedAcquire ??= () {
      _queuedAcquire = null;
      _holdsSlot = true;
      if (!mounted || !_visible || _controller != null || _failed) {
        _holdsSlot = false;
        ExploreGridVideo._release();
        return;
      }
      _initController();
    };
    ExploreGridVideo._enqueue(_queuedAcquire!);
  }

  Future<void> _initController() async {
    if (!mounted) {
      if (_holdsSlot) {
        _holdsSlot = false;
        ExploreGridVideo._release();
      }
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(false);
      if (!mounted || _controller != controller) {
        await controller.dispose();
        if (_holdsSlot) {
          _holdsSlot = false;
          ExploreGridVideo._release();
        }
        return;
      }

      setState(() {
        _ready = true;
        _loading = false;
      });
      if (_visible) {
        await controller.seekTo(Duration.zero);
        await controller.play();
        _startPreviewLoop(controller);
      }
    } catch (_) {
      await controller.dispose();
      _controller = null;
      if (_holdsSlot) {
        _holdsSlot = false;
        ExploreGridVideo._release();
      }
      if (!mounted) return;
      setState(() {
        _ready = false;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _disposeController() {
    _stopPreviewLoop();
    final controller = _controller;
    if (controller != null) {
      controller.dispose();
      _controller = null;
    }
    _ready = false;
    _loading = false;
    if (_holdsSlot) {
      _holdsSlot = false;
      ExploreGridVideo._release();
    }
  }

  Future<void> _retry() async {
    _cancelQueueEntry();
    _disposeController();
    setState(() {
      _failed = false;
      _ready = false;
    });
    if (_visible) _requestController();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return VisibilityDetector(
      key: Key('explore-video-${widget.url.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (widget.thumbnailUrl != null &&
                widget.thumbnailUrl!.isNotEmpty)
              NetworkPhoto(
                url: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    ColoredBox(color: fv.elevatedSurface),
              )
            else
              ColoredBox(color: fv.elevatedSurface),
            if (_loading && !_ready)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FirstVueColors.teal,
                  ),
                ),
              ),
            if (_failed)
              ColoredBox(
                color: fv.elevatedSurface,
                child: Center(
                  child: IconButton(
                    onPressed: _retry,
                    tooltip: 'Retry video',
                    icon: Icon(Icons.refresh_rounded, color: fv.secondaryText),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
