import 'package:flutter/material.dart';

import 'html_video_impl.dart'
    if (dart.library.js_interop) 'html_video_impl_web.dart' as impl;

/// HTML `<video>` surface for Flutter web (iPhone Safari can show MOV/MP4).
class HtmlVideoView extends StatelessWidget {
  final String url;
  final bool autoplay;
  final bool controls;
  final bool looping;
  final bool muted;
  final BoxFit fit;

  const HtmlVideoView({
    super.key,
    required this.url,
    this.autoplay = false,
    this.controls = false,
    this.looping = false,
    this.muted = true,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildHtmlVideo(
      url: url,
      autoplay: autoplay,
      controls: controls,
      looping: looping,
      muted: muted,
      fit: fit,
    );
  }
}
