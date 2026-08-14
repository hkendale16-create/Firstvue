import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../screens/full_screen_media_viewer.dart';
import '../services/media_type_helpers.dart';
import '../theme/firstvue_theme.dart';
import 'html_video_view.dart';
import 'network_photo.dart';

/// Thumbnail for a signed network URL.
///
/// On web, photos use an HTML `<img>` and clips use `<video playsinline>` so
/// iPhone Safari can show Supabase media that CanvasKit `fetch()` blocks.
class SignedMediaThumbnail extends StatelessWidget {
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

  bool get _treatAsVideo =>
      isVideo || mediaTypeFromMetadata(pathOrUrl: url) == 'video';

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_treatAsVideo) {
      child = kIsWeb
          ? Stack(
              fit: StackFit.expand,
              children: [
                HtmlVideoView(
                  key: ValueKey(url),
                  url: url,
                  fit: fit,
                  muted: true,
                  borderRadius: borderRadius,
                ),
                const IgnorePointer(child: _PlayOverlay(compact: true)),
              ],
            )
          : _IoVideoThumb(url: url, fit: fit);
    } else {
      child = NetworkPhoto(
        url: url,
        width: width,
        height: height,
        fit: fit,
        borderRadius: kIsWeb ? borderRadius : null,
      );
    }

    if (!kIsWeb && borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }

    return child;
  }
}

class _IoVideoThumb extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const _IoVideoThumb({required this.url, required this.fit});

  @override
  State<_IoVideoThumb> createState() => _IoVideoThumbState();
}

class _IoVideoThumbState extends State<_IoVideoThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _IoVideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _init();
    }
  }

  Future<void> _init() async {
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
      setState(() => _ready = true);
    } catch (_) {
      await controller.dispose();
      if (mounted && _controller == controller) {
        setState(() => _controller = null);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready && _controller != null) {
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

    return const ColoredBox(
      color: FirstVueColors.elevatedSurface,
      child: Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 36),
      ),
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
      builder: (ctx) =>
          _SignedMediaViewerDialog(url: url, isVideo: isVideo, title: title),
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

  bool get _treatAsVideo =>
      widget.isVideo || mediaTypeFromMetadata(pathOrUrl: widget.url) == 'video';

  @override
  void initState() {
    super.initState();
    if (_treatAsVideo && !kIsWeb) {
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
                      widget.title ?? (_treatAsVideo ? 'VIDEO' : 'PHOTO'),
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
            Flexible(child: _treatAsVideo ? _buildVideo() : _buildImage()),
            if (!kIsWeb && _treatAsVideo && _ready && !_failed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _togglePlay,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
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
      child: NetworkPhoto(
        url: widget.url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Colors.white38,
                size: 48,
              ),
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
    if (kIsWeb) {
      return SizedBox(
        height: 360,
        width: double.infinity,
        child: HtmlVideoView(
          url: widget.url,
          autoplay: true,
          controls: true,
          looping: true,
          muted: false,
          fit: BoxFit.contain,
        ),
      );
    }

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

/// Opens a dedicated full-screen page for images/videos (not a floating modal).
void openSignedMedia(
  BuildContext context, {
  required String url,
  required bool isVideo,
  String? title,
}) {
  if (isVideo) {
    openFullScreenVideoPlayer(
      context,
      url: url,
      title: title ?? 'VIDEO',
      loop: true,
    );
  } else {
    openFullScreenImageViewer(
      context,
      items: [FullScreenMediaItem(url: url, isVideo: false)],
      title: title ?? 'PHOTO',
    );
  }
}
