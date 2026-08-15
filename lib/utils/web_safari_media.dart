import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// iOS Safari kills the Flutter web tab ("A problem repeatedly occurred") when
/// CanvasKit composites with many HTML platform views / video decoders.
///
/// Use these gates on web only. Native apps keep richer media behavior.
bool get webAvoidStackedMediaTabs => kIsWeb;

/// Do not create [VideoPlayerController] / HTML `<video>` for feed or grid
/// previews on web — posters + tap-to-fullscreen only.
bool get webAvoidInlineVideoPreview => kIsWeb;

/// Tighter scroll cache on web so off-screen HTML `<img>` platform views
/// dispose sooner. Native keeps the framework default.
ScrollCacheExtent? get webScrollCacheExtent =>
    kIsWeb ? const ScrollCacheExtent.pixels(180) : null;
