import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Non-web fallback — real playback uses [video_player] instead.
Widget buildHtmlVideo({
  required String url,
  required bool autoplay,
  required bool controls,
  required bool looping,
  required bool muted,
  required BoxFit fit,
  BorderRadius? borderRadius,
}) {
  return const ColoredBox(
    color: FirstVueColors.elevatedSurface,
    child: Center(
      child: Icon(Icons.videocam_outlined, color: Colors.white38, size: 28),
    ),
  );
}
