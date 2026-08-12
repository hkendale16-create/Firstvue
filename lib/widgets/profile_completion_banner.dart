import 'package:flutter/material.dart';

import '../services/profile_completion_service.dart';
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
                    style: TextStyle(
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
