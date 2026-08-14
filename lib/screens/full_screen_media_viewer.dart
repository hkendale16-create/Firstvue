import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../navigation/firstvue_page_route.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/html_video_view.dart';
import '../widgets/network_photo.dart';

class FullScreenMediaItem {
  final String url;
  final bool isVideo;
  final String? caption;

  const FullScreenMediaItem({
    required this.url,
    required this.isVideo,
    this.caption,
  });
}

/// Opens a dedicated full-screen image gallery (pinch zoom + swipe).
Future<void> openFullScreenImageViewer(
  BuildContext context, {
  required List<FullScreenMediaItem> items,
  int initialIndex = 0,
  String? title,
  Widget? footer,
}) {
  final images = items.where((e) => !e.isVideo).toList();
  if (images.isEmpty) return Future.value();
  var start = initialIndex;
  if (start < 0 || start >= images.length) start = 0;
  return Navigator.of(context).push(
    FirstVuePageRoute(
      builder: (_) => FullScreenImageViewerPage(
        items: images,
        initialIndex: start,
        title: title,
        footer: footer,
      ),
    ),
  );
}

/// Opens a dedicated full-screen video player.
Future<void> openFullScreenVideoPlayer(
  BuildContext context, {
  required String url,
  String? title,
  bool loop = true,
  Widget? footer,
}) {
  return Navigator.of(context).push(
    FirstVuePageRoute(
      builder: (_) => FullScreenVideoPlayerPage(
        url: url,
        title: title,
        loop: loop,
        footer: footer,
      ),
    ),
  );
}

class FullScreenImageViewerPage extends StatefulWidget {
  final List<FullScreenMediaItem> items;
  final int initialIndex;
  final String? title;
  final Widget? footer;

  const FullScreenImageViewerPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.title,
    this.footer,
  });

  @override
  State<FullScreenImageViewerPage> createState() =>
      _FullScreenImageViewerPageState();
}

class _FullScreenImageViewerPageState extends State<FullScreenImageViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'PHOTO'),
        actions: [
          if (widget.items.length > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_index + 1}/${widget.items.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final item = widget.items[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: NetworkPhoto(
                      url: item.url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.items[_index].caption?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                widget.items[_index].caption!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          if (widget.footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: widget.footer!,
              ),
            ),
        ],
      ),
    );
  }
}

class FullScreenVideoPlayerPage extends StatefulWidget {
  final String url;
  final String? title;
  final bool loop;
  final Widget? footer;

  const FullScreenVideoPlayerPage({
    super.key,
    required this.url,
    this.title,
    this.loop = true,
    this.footer,
  });

  @override
  State<FullScreenVideoPlayerPage> createState() =>
      _FullScreenVideoPlayerPageState();
}

class _FullScreenVideoPlayerPageState extends State<FullScreenVideoPlayerPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _init();
    }
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.loop);
      await controller.setVolume(1);
      await controller.play();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() {
        _ready = true;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    if (c == null || !_ready) return;
    _muted = !_muted;
    await c.setVolume(_muted ? 0 : 1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'VIDEO'),
        actions: [
          if (!kIsWeb)
            IconButton(
              onPressed: _ready ? _toggleMute : null,
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: kIsWeb
                ? HtmlVideoView(
                    url: widget.url,
                    autoplay: true,
                    controls: true,
                    looping: widget.loop,
                    muted: false,
                    fit: BoxFit.contain,
                  )
                : GestureDetector(
              onTap: _togglePlay,
              child: Center(
                child: _failed
                    ? const Text(
                        'Unable to play this video.',
                        style: TextStyle(color: Colors.white54),
                      )
                    : !_ready || c == null
                        ? const CircularProgressIndicator(
                            color: FirstVueColors.teal,
                          )
                        : AspectRatio(
                            aspectRatio: c.value.aspectRatio == 0
                                ? 9 / 16
                                : c.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(c),
                                if (!c.value.isPlaying)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 42,
                                    ),
                                  ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
          if (!kIsWeb && _ready && c != null)
            VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: FirstVueColors.teal,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          if (widget.footer != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: widget.footer!,
              ),
            ),
        ],
      ),
    );
  }
}
