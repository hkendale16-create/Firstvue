import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import 'html_photo_impl.dart'
    if (dart.library.js_interop) 'html_photo_impl_web.dart'
    as html_photo;

/// Network photo that uses an HTML `<img>` on Flutter web.
///
/// CanvasKit `Image.network` fetches bytes with CORS. Signed Supabase URLs
/// often fail that check, so the photo never paints. An `<img>` still displays
/// the file. Flutter [ClipRRect] cannot clip platform views — pass
/// [borderRadius] so rounding is applied in CSS.
class NetworkPhoto extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const NetworkPhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return errorBuilder?.call(
            context,
            StateError('empty image url'),
            StackTrace.empty,
          ) ??
          _broken();
    }

    Widget child;
    if (kIsWeb) {
      child = html_photo.buildHtmlPhoto(
        url: url,
        fit: fit,
        borderRadius: borderRadius,
      );
    } else {
      child = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder ?? (_, _, _) => _broken(),
      );
      if (borderRadius != null) {
        child = ClipRRect(borderRadius: borderRadius!, child: child);
      }
    }

    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }
    return child;
  }

  Widget _broken() {
    return const ColoredBox(
      color: FirstVueColors.elevatedSurface,
      child: Icon(Icons.broken_image_outlined, color: Colors.white38),
    );
  }
}
