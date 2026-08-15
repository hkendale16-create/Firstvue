import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';

/// Phase 1 empty LIVE shell — discovery UI arrives in Phase 2+.
class LiveHomeShellScreen extends StatelessWidget {
  final VoidCallback? onReturnToVue;

  const LiveHomeShellScreen({super.key, this.onReturnToVue});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return ColoredBox(
      color: fv.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LIVE',
                style: TextStyle(
                  color: FirstVueColors.coral,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Real-time discovery is coming next.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fv.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Switch back to VUE anytime. Your account, feed, and navigation stay the same.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fv.secondaryText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (onReturnToVue != null) ...[
                const SizedBox(height: 22),
                TextButton(
                  onPressed: onReturnToVue,
                  style: TextButton.styleFrom(
                    foregroundColor: FirstVueColors.gold,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Back to VUE',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
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
