import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildHtmlVideo({
  required String url,
  required bool autoplay,
  required bool controls,
  required bool looping,
  required bool muted,
  required BoxFit fit,
  BorderRadius? borderRadius,
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
      video.preload = autoplay ? 'auto' : 'metadata';
      video.setAttribute('webkit-playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover';
      video.style.backgroundColor = '#151B22';
      if (borderRadius != null) {
        final r = borderRadius.topLeft.x;
        video.style.borderRadius = '${r}px';
        video.style.overflow = 'hidden';
      }
      video.src = url;
    },
  );
}
