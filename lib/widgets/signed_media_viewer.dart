import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/firstvue_theme.dart';

/// Thumbnail for a signed network URL — images load directly; videos show the
/// first frame once the controller initializes.
class SignedMediaThumbnail extends StatefulWidget {
  final String url;
  final bool isVideo;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const SignedMediaThumbnail({
    super.key,
    required this.url,
    required this.isVideo,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<SignedMediaThumbnail> createState() => _SignedMediaThumbnailState();
}

class _SignedMediaThumbnailState extends State<SignedMediaThumbnail> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant SignedMediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url || widget.isVideo != oldWidget.isVideo) {
      _disposeVideo();
      if (widget.isVideo) {
        _initVideo();
      } else {
        setState(() {
          _videoReady = false;
          _videoFailed = false;
        });
      }
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.pause();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoReady = true;
        _videoFailed = false;
      });
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _videoFailed = true);
    }
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.isVideo) {
      child = _buildVideoThumbnail();
    } else {
      child = Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder(
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FirstVueColors.gold,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _placeholder(
          child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
        ),
      );
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    if (widget.width != null || widget.height != null) {
      child = SizedBox(width: widget.width, height: widget.height, child: child);
    }

    return child;
  }

  Widget _buildVideoThumbnail() {
    if (_videoReady && _controller != null) {
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
          const _PlayOverlay(compact: true),
        ],
      );
    }

    if (_videoFailed) {
      return _placeholder(
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 28),
            SizedBox(height: 4),
            Text('Video', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      );
    }

    return _placeholder(
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: FirstVueColors.teal,
          ),
        ),
      ),
    );
  }

  Widget _placeholder({required Widget child}) {
    return ColoredBox(
      color: FirstVueColors.elevatedSurface,
      child: child,
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  final bool compact;

  const _PlayOverlay({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(compact ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: compact ? 28 : 40,
        ),
      ),
    );
  }
}

/// Full-screen viewer for images (pinch-zoom) and videos (in-app player).
class SignedMediaViewer {
  SignedMediaViewer._();

  static Future<void> show(
    BuildContext context, {
    required String url,
    required bool isVideo,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _SignedMediaViewerDialog(
        url: url,
        isVideo: isVideo,
        title: title,
      ),
    );
  }
}

class _SignedMediaViewerDialog extends StatefulWidget {
  final String url;
  final bool isVideo;
  final String? title;

  const _SignedMediaViewerDialog({
    required this.url,
    required this.isVideo,
    this.title,
  });

  @override
  State<_SignedMediaViewerDialog> createState() =>
      _SignedMediaViewerDialogState();
}

class _SignedMediaViewerDialogState extends State<_SignedMediaViewerDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _failed = true);
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (controller.value.isPlaying) {
      controller.pause();
      setState(() => _playing = false);
    } else {
      controller.play();
      setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10151B),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: MediaQuery.of(context).size.width,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title ?? (widget.isVideo ? 'VIDEO' : 'PHOTO'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Flexible(
              child: widget.isVideo ? _buildVideo() : _buildImage(),
            ),
            if (widget.isVideo && _ready && !_failed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _togglePlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(_playing ? 'PAUSE' : 'PLAY'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            ),
          );
        },
        errorBuilder: (_, _, _) => const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
              SizedBox(height: 12),
              Text(
                'Unable to load this image.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_failed) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 48),
            SizedBox(height: 12),
            Text(
              'Unable to play this video.',
              style: TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_ready || _controller == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(color: FirstVueColors.teal),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller!),
            if (!_playing) const _PlayOverlay(),
          ],
        ),
      ),
    );
  }
}

/// Opens the fullscreen viewer for a signed network URL.
void openSignedMedia(
  BuildContext context, {
  required String url,
  required bool isVideo,
  String? title,
}) {
  SignedMediaViewer.show(
    context,
    url: url,
    isVideo: isVideo,
    title: title,
  );
}
