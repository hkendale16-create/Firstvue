import 'package:flutter/material.dart';

/// Non-web fallback; web uses an HTML `<img>` so signed URLs can display.
Widget buildHtmlPhoto({
  required String url,
  required BoxFit fit,
  BorderRadius? borderRadius,
}) {
  return Image.network(
    url,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
  );
}
