import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/feature_flags.dart';
import '../services/live_stream_service.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_ephemeral_toast.dart';
import 'media_picker_sheet.dart';

/// Photo | Video | Go Live composer actions (Go Live sits next to Video).
class ProfileComposerMediaActions extends StatelessWidget {
  final bool enabled;
  final ValueChanged<List<XFile>> onMediaPicked;
  final VoidCallback? onGoLive;

  const ProfileComposerMediaActions({
    super.key,
    required this.enabled,
    required this.onMediaPicked,
    this.onGoLive,
  });

  Future<void> _pickPhotos(BuildContext context) async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty) return;
    onMediaPicked(files);
  }

  Future<void> _pickVideos(BuildContext context) async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    onMediaPicked([video]);
  }

  Future<void> _goLive(BuildContext context) async {
    if (onGoLive != null) {
      onGoLive!();
      return;
    }
    final eligibility = await LiveStreamService.fetchMyEligibility();
    final eligible = eligibility?.isEligible ?? false;
    if (!context.mounted) return;
    FirstVueEphemeralToast.show(
      context,
      message: eligible
          ? 'Live streaming is coming soon. You meet the eligibility requirements.'
          : 'Go Live unlocks with a verified business and '
                '${LiveStreamEligibility.minFollowers}+ followers.',
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionChip(
          icon: Icons.photo_outlined,
          label: 'Photo',
          onTap: enabled ? () => _pickPhotos(context) : null,
        ),
        const SizedBox(width: 8),
        _ActionChip(
          icon: Icons.videocam_outlined,
          label: 'Video',
          onTap: enabled ? () => _pickVideos(context) : null,
        ),
        const SizedBox(width: 8),
        if (FeatureFlags.liveStreamingEnabled)
          _ActionChip(
            icon: Icons.sensors,
            label: 'Go Live',
            accent: FirstVueColors.coral,
            onTap: enabled ? () => _goLive(context) : null,
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? accent;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? FirstVueColors.teal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .85),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
