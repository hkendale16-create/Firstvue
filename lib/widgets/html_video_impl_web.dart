import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildHtmlVideo({
  required String url,
  required bool autoplay,
  required bool controls,
  required bool looping,
  required bool muted,
  required BoxFit fit,
}) {
  return HtmlElementView.fromTagName(
    tagName: 'video',
    onElementCreated: (element) {
      final video = element as web.HTMLVideoElement;
      video.controls = controls;
      video.autoplay = autoplay;
      video.loop = looping;
      video.muted = muted;
      video.playsInline = true;
      // Avoid metadata decode storms from many thumbs; full-screen sets autoplay.
      video.preload = autoplay ? 'auto' : 'none';
      video.setAttribute('webkit-playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover';
      video.style.backgroundColor = '#151B22';
      video.src = url;
    },
  );
}
