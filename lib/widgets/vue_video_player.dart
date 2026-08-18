import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/firstvue_theme.dart';
import 'network_photo.dart';

/// Full video player with mute toggle and progress bar for videos longer than 10s.
class VueVideoPlayer extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final double? aspectRatio;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool autoPlay;
  final bool startMuted;
  final bool active;

  final bool showChrome;
  final VoidCallback? onPlaybackStarted;

  const VueVideoPlayer({
    super.key,
    required this.url,
    this.thumbnailUrl,
    this.aspectRatio,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.autoPlay = true,
    this.startMuted = true,
    this.active = true,
    this.showChrome = true,
    this.onPlaybackStarted,
  });

  @override
  State<VueVideoPlayer> createState() => _VueVideoPlayerState();
}

class _VueVideoPlayerState extends State<VueVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = true;
  bool _showLongProgress = false;
  bool _notifiedPlay = false;

  @override
  void initState() {
    super.initState();
    _muted = widget.startMuted;
    _initController();
  }

  @override
  void didUpdateWidget(covariant VueVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _initController();
      return;
    }
    if (oldWidget.active != widget.active) {
      _syncActive();
    }
  }

  Future<void> _syncActive() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (widget.active && widget.autoPlay) {
      await controller.play();
      _notifyPlay();
    } else {
      await controller.pause();
    }
    if (mounted) setState(() {});
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }

      final duration = controller.value.duration;
      if (widget.autoPlay && widget.active) {
        await controller.play();
        _notifyPlay();
      }

      setState(() {
        _ready = true;
        _showLongProgress = duration.inSeconds > 10;
      });
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _failed = true);
    }
  }

  void _notifyPlay() {
    if (_notifiedPlay) return;
    _notifiedPlay = true;
    widget.onPlaybackStarted?.call();
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _ready = false;
    _failed = false;
    _notifiedPlay = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_muted;
    await controller.setVolume(next ? 0 : 1);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
      _notifyPlay();
    }
    if (mounted) setState(() {});
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        alignment: Alignment.center,
        color: FirstVueColors.elevatedSurface,
        child: const Icon(Icons.videocam_off_outlined, color: Colors.white38),
      );
    }

    if (!_ready || _controller == null) {
      final poster = (widget.thumbnailUrl ?? '').trim();
      return Container(
        alignment: Alignment.center,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster.startsWith('http'))
              NetworkPhoto(url: poster, fit: widget.fit),
            const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          ],
        ),
      );
    }

    final controller = _controller!;
    final ratio = widget.aspectRatio ?? controller.value.aspectRatio;

    Widget video = AspectRatio(
      aspectRatio: ratio,
      child: VideoPlayer(controller),
    );

    if (widget.borderRadius != null) {
      video = ClipRRect(borderRadius: widget.borderRadius!, child: video);
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          video,
          if (!controller.value.isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .35),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          if (widget.showChrome)
            Positioned(
              right: 8,
              bottom: _showLongProgress ? 36 : 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .55),
                  foregroundColor: Colors.white,
                ),
                onPressed: _toggleMute,
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                ),
              ),
            ),
          if (widget.showChrome && _showLongProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final position = controller.value.position;
                  final duration = controller.value.duration;
                  final progress = duration.inMilliseconds == 0
                      ? 0.0
                      : position.inMilliseconds / duration.inMilliseconds;

                  return Container(
                    color: Colors.black.withValues(alpha: .55),
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: Colors.white24,
                            color: FirstVueColors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
