import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// HTML `<img>` so the browser displays signed Supabase URLs without CORS fetch.
Widget buildHtmlPhoto({
  required String url,
  required BoxFit fit,
  BorderRadius? borderRadius,
}) {
  return HtmlElementView.fromTagName(
    tagName: 'img',
    onElementCreated: (element) {
      final img = element as web.HTMLImageElement;
      img.src = url;
      img.alt = '';
      img.draggable = false;
      img.decoding = 'async';
      img.style.width = '100%';
      img.style.height = '100%';
      img.style.objectFit = fit == BoxFit.contain ? 'contain' : 'cover';
      img.style.border = '0';
      img.style.display = 'block';
      if (borderRadius != null) {
        img.style.borderRadius = _cssRadius(borderRadius);
        img.style.overflow = 'hidden';
      }
    },
  );
}

String _cssRadius(BorderRadius radius) {
  final tl = radius.topLeft.x;
  final tr = radius.topRight.x;
  final br = radius.bottomRight.x;
  final bl = radius.bottomLeft.x;
  if (tl == tr && tr == br && br == bl) {
    return '${tl}px';
  }
  return '${tl}px ${tr}px ${br}px ${bl}px';
}
