import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/firstvue_theme.dart';

/// Session-level mute preference for VUE (and reusable) autoplay videos.
class VueAudioPreference {
  VueAudioPreference._();

  static bool muted = true;

  static void setMuted(bool value) {
    muted = value;
  }
}

/// Full video player with mute toggle and optional progress for longer clips.
///
/// Uses [VueAudioPreference] so mute state persists across VUE cards in-session.
/// When [isActive] is false the player pauses (for off-screen PageView pages).
class VueVideoPlayer extends StatefulWidget {
  final String url;
  final double? aspectRatio;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool autoPlay;
  final bool startMuted;
  final bool isActive;
  final bool showMuteControl;
  final bool showProgress;
  final Alignment muteAlignment;

  const VueVideoPlayer({
    super.key,
    required this.url,
    this.aspectRatio,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.autoPlay = true,
    this.startMuted = true,
    this.isActive = true,
    this.showMuteControl = true,
    this.showProgress = true,
    this.muteAlignment = Alignment.topRight,
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

  @override
  void initState() {
    super.initState();
    // Session preference wins; default is muted until the user unmutes.
    _muted = VueAudioPreference.muted;
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
    if (oldWidget.isActive != widget.isActive) {
      _syncActivePlayback();
    }
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
      if (widget.autoPlay && widget.isActive) {
        await controller.play();
      } else {
        await controller.pause();
      }

      setState(() {
        _ready = true;
        _showLongProgress =
            widget.showProgress && duration.inSeconds > 10;
      });
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _syncActivePlayback() async {
    final controller = _controller;
    if (controller == null || !_ready) return;
    if (widget.isActive && widget.autoPlay) {
      await controller.play();
    } else {
      await controller.pause();
    }
    if (mounted) setState(() {});
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _ready = false;
    _failed = false;
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
    VueAudioPreference.setMuted(next);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !widget.isActive) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
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
      return Container(
        alignment: Alignment.center,
        color: FirstVueColors.elevatedSurface,
        child: const CircularProgressIndicator(color: FirstVueColors.teal),
      );
    }

    final controller = _controller!;
    final ratio = widget.aspectRatio ??
        (controller.value.aspectRatio == 0
            ? 9 / 16
            : controller.value.aspectRatio);

    Widget video = SizedBox.expand(
      child: FittedBox(
        fit: widget.fit == BoxFit.contain ? BoxFit.contain : BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width == 0
              ? ratio
              : controller.value.size.width,
          height: controller.value.size.height == 0
              ? 1
              : controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );

    if (widget.borderRadius != null) {
      video = ClipRRect(borderRadius: widget.borderRadius!, child: video);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          behavior: HitTestBehavior.opaque,
          child: video,
        ),
        if (!controller.value.isPlaying && widget.isActive)
          IgnorePointer(
            child: Center(
              child: Container(
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
            ),
          ),
        if (widget.showMuteControl)
          Align(
            alignment: widget.muteAlignment,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleMute,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_showLongProgress)
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
    );
  }
}
