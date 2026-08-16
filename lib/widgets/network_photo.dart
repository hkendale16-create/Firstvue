import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/firstvue_theme.dart';

/// Network photo that prefers an HTML `<img>` on Flutter web.
///
/// CanvasKit fetches bytes with CORS. Signed Supabase URLs often send
/// cookies while the host replies `Access-Control-Allow-Origin: *`, which
/// browsers block. An `<img>` still displays the file.
///
/// On web, the HTML element is only mounted while mostly visible so Offstage
/// tabs and long feeds do not accumulate platform views until Safari OOMs.
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

    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (kIsWeb) {
      return _VisibilityGatedNetworkPhoto(
        url: url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder,
        cacheWidth: _decodePx(width, dpr),
        cacheHeight: _decodePx(height, dpr),
      );
    }

    return _networkImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
      useHtmlElement: false,
      cacheWidth: _decodePx(width, dpr),
      cacheHeight: _decodePx(height, dpr),
    );
  }

  static int? _decodePx(double? logical, double dpr) {
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * dpr).round().clamp(1, 4096);
  }

  static Widget _networkImage({
    required String url,
    double? width,
    double? height,
    required BoxFit fit,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    required bool useHtmlElement,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      webHtmlElementStrategy: useHtmlElement
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.never,
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

  static Widget _broken() {
    return const ColoredBox(
      color: FirstVueColors.elevatedSurface,
      child: Icon(Icons.broken_image_outlined, color: Colors.white38),
    );
  }
}

class _VisibilityGatedNetworkPhoto extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final int? cacheWidth;
  final int? cacheHeight;

  const _VisibilityGatedNetworkPhoto({
    required this.url,
    this.width,
    this.height,
    required this.fit,
    this.errorBuilder,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  State<_VisibilityGatedNetworkPhoto> createState() =>
      _VisibilityGatedNetworkPhotoState();
}

class _VisibilityGatedNetworkPhotoState
    extends State<_VisibilityGatedNetworkPhoto> {
  bool _mountImage = false;
  Timer? _releaseTimer;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.12;
    if (visible) {
      _releaseTimer?.cancel();
      if (!_mountImage && mounted) {
        setState(() => _mountImage = true);
      }
      return;
    }
    if (!_mountImage) return;
    _releaseTimer?.cancel();
    // Free the HTML platform view quickly once scrolled/offstaged away.
    _releaseTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() => _mountImage = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('net-photo-${widget.url.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _mountImage
          ? NetworkPhoto._networkImage(
              url: widget.url,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: widget.errorBuilder,
              useHtmlElement: true,
              cacheWidth: widget.cacheWidth,
              cacheHeight: widget.cacheHeight,
            )
          : ColoredBox(
              color: FirstVueColors.elevatedSurface,
              child: SizedBox(width: widget.width, height: widget.height),
            ),
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
