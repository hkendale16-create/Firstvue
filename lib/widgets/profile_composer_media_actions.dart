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
  /// Icon-first row for Option 4 Create Post (light surfaces).
  final bool compact;

  const ProfileComposerMediaActions({
    super.key,
    required this.enabled,
    required this.onMediaPicked,
    this.onGoLive,
    this.compact = false,
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
    final fv = context.fv;
    final labelColor = compact ? fv.secondaryText : Colors.white.withValues(alpha: .85);

    return Row(
      children: [
        _ActionChip(
          icon: Icons.photo_outlined,
          label: 'Photo',
          compact: compact,
          labelColor: labelColor,
          onTap: enabled ? () => _pickPhotos(context) : null,
        ),
        SizedBox(width: compact ? 4 : 8),
        _ActionChip(
          icon: Icons.videocam_outlined,
          label: 'Video',
          compact: compact,
          labelColor: labelColor,
          onTap: enabled ? () => _pickVideos(context) : null,
        ),
        SizedBox(width: compact ? 4 : 8),
        if (FeatureFlags.liveStreamingEnabled)
          _ActionChip(
            icon: Icons.sensors,
            label: 'Go Live',
            accent: FirstVueColors.coral,
            compact: compact,
            labelColor: labelColor,
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
  final bool compact;
  final Color labelColor;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.labelColor,
    this.onTap,
    this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? FirstVueColors.teal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 20 : 18, color: color),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
