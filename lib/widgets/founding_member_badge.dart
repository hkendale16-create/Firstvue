import 'package:flutter/material.dart';

import '../services/profile_recognition_service.dart';
import '../theme/firstvue_theme.dart';

/// Tasteful profile recognition line (Founding Member / Builder).
class FoundingMemberBadge extends StatelessWidget {
  final ProfileRecognitionBadge badge;
  final bool centered;

  const FoundingMemberBadge({
    super.key,
    required this.badge,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        badge.displayLabel,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: FirstVueColors.gold.withValues(alpha: 0.92),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Loads and shows an active recognition badge for [profileId], if any.
class FoundingMemberBadgeLoader extends StatefulWidget {
  final String profileId;
  final bool centered;

  const FoundingMemberBadgeLoader({
    super.key,
    required this.profileId,
    this.centered = true,
  });

  @override
  State<FoundingMemberBadgeLoader> createState() =>
      _FoundingMemberBadgeLoaderState();
}

class _FoundingMemberBadgeLoaderState extends State<FoundingMemberBadgeLoader> {
  ProfileRecognitionBadge? _badge;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FoundingMemberBadgeLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) _load();
  }

  Future<void> _load() async {
    final badge =
        await ProfileRecognitionService.fetchActiveForProfile(widget.profileId);
    if (!mounted) return;
    setState(() => _badge = badge);
  }

  @override
  Widget build(BuildContext context) {
    final badge = _badge;
    if (badge == null) return const SizedBox.shrink();
    return FoundingMemberBadge(badge: badge, centered: widget.centered);
  }
}
