import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Network photo that prefers an HTML `<img>` on Flutter web.
///
/// CanvasKit fetches bytes with CORS. Signed Supabase URLs often send
/// cookies while the host replies `Access-Control-Allow-Origin: *`, which
/// browsers block. An `<img>` still displays the file.
class NetworkPhoto extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const NetworkPhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
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

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return ColoredBox(
          color: FirstVueColors.elevatedSurface,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FirstVueColors.gold,
              ),
            ),
          ),
        );
      },
      errorBuilder: errorBuilder ?? (_, _, _) => _broken(),
    );
  }

  Widget _broken() {
    return const ColoredBox(
      color: FirstVueColors.elevatedSurface,
      child: Icon(Icons.broken_image_outlined, color: Colors.white38),
    );
  }
}

/// Circular avatar that loads remote images via [NetworkPhoto] (web-safe).
///
/// Prefer this over [CircleAvatar.backgroundImage] with [NetworkImage] —
/// [NetworkImage] still uses CanvasKit `fetch()` and fails on signed URLs.
class NetworkCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const NetworkCircleAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.placeholder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final bg = backgroundColor ?? FirstVueColors.elevatedSurface;
    final url = imageUrl?.trim() ?? '';
    final hasUrl = url.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: hasUrl
            ? NetworkPhoto(
                url: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder:
                    errorBuilder ??
                    (context, error, stack) =>
                        ColoredBox(color: bg, child: _placeholderChild()),
              )
            : ColoredBox(color: bg, child: _placeholderChild()),
      ),
    );
  }

  Widget _placeholderChild() {
    return Center(
      child:
          placeholder ??
          Icon(
            Icons.person_rounded,
            size: radius,
            color: FirstVueColors.gold,
          ),
    );
  }
}
