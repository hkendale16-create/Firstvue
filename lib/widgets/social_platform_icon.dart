import 'package:flutter/material.dart';

IconData socialPlatformIcon(String platform) {
  final normalized = platform.toLowerCase();
  if (normalized.contains('youtube')) return Icons.play_circle_fill_rounded;
  if (normalized.contains('instagram')) return Icons.camera_alt_outlined;
  if (normalized.contains('facebook')) return Icons.facebook_rounded;
  if (normalized.contains('tiktok')) return Icons.music_note_rounded;
  if (normalized.contains('x') || normalized.contains('twitter')) {
    return Icons.alternate_email_rounded;
  }
  if (normalized.contains('linkedin')) return Icons.work_outline_rounded;
  return Icons.link_rounded;
}

Color socialPlatformColor(String platform) {
  final normalized = platform.toLowerCase();
  if (normalized.contains('youtube')) return const Color(0xFFFF0033);
  if (normalized.contains('instagram')) return const Color(0xFFE1306C);
  if (normalized.contains('facebook')) return const Color(0xFF1877F2);
  if (normalized.contains('tiktok')) return const Color(0xFF25F4EE);
  if (normalized.contains('linkedin')) return const Color(0xFF0A66C2);
  return const Color(0xFFD8B56A);
}
