import 'package:flutter/material.dart';

import 'network_photo.dart';

/// Circular avatar that uses [NetworkPhoto] so signed URLs paint on web.
class NetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget fallback;

  const NetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final url = imageUrl?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: url != null && url.isNotEmpty
          ? NetworkPhoto(
              url: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(radius),
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}
