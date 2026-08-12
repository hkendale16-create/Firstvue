import 'package:flutter/material.dart';

import '../services/profile_completion_service.dart';
import '../services/profile_media_service.dart';
import '../services/user_profile_service.dart';
import '../theme/firstvue_theme.dart';

/// Subtle borderless banner showing completion % and the next missing field.
class ProfileCompletionBanner extends StatelessWidget {
  final ProfileCompletionResult result;
  final VoidCallback? onTap;
  final String? entityLabel;

  const ProfileCompletionBanner({
    super.key,
    required this.result,
    this.onTap,
    this.entityLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (result.totalCount == 0 || result.isComplete) {
      return const SizedBox.shrink();
    }

    final fv = context.fv;
    final next = result.nextMissing;
    final label = entityLabel == null ? 'Profile' : entityLabel!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label ${result.percent}% complete',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${result.filledCount}/${result.totalCount}',
                    style: const TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: result.ratio.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: fv.elevatedSurface,
                  color: FirstVueColors.gold,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Next: add $next',
                  style: TextStyle(
                    color: fv.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads user completion from existing profile + avatar fields.
class UserProfileCompletionBanner extends StatefulWidget {
  final String userId;
  final VoidCallback? onTap;

  const UserProfileCompletionBanner({
    super.key,
    required this.userId,
    this.onTap,
  });

  @override
  State<UserProfileCompletionBanner> createState() =>
      _UserProfileCompletionBannerState();
}

class _UserProfileCompletionBannerState
    extends State<UserProfileCompletionBanner> {
  ProfileCompletionResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant UserProfileCompletionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    final profile = await UserProfileService.fetchProfileForUser(widget.userId);
    final images = await ProfileMediaService.fetchProfileImagesForUser(
      widget.userId,
    );
    if (!mounted) return;
    final fields = <String, dynamic>{
      'display_name': profile?.displayName,
      'username': profile?.username,
      'bio': profile?.bio,
      'city': profile?.city,
      'website': profile?.website,
      'phone': profile?.phone,
      'has_avatar': images.avatar != null,
    };
    setState(() {
      _result = ProfileCompletionService.score(
        type: ProfileEntityType.user,
        fields: fields,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ProfileCompletionBanner(result: result, onTap: widget.onTap),
    );
  }
}
