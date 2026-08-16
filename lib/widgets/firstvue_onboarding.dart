import 'package:flutter/material.dart';

import '../services/onboarding_store.dart';
import 'firstvue_emblem.dart';
import 'firstvue_section_tip.dart';

const _kDialogBg = Color(0xFF10151B);
const _kGold = Color(0xFFD8B56A);
const _kTeal = Color(0xFF3DD9C9);

/// First signed-in visit or post-update session: welcome / what's new, then tips.
Future<void> showFirstLaunchExperience(
  BuildContext context, {
  TutorialSection? initialSection,
}) async {
  var tipsOn = false;

  final prompt = await OnboardingStore.pendingPrompt();
  if (prompt == TutorialPromptKind.welcome) {
    if (!context.mounted) return;
    final takeTour = await FirstVueWelcomeDialog.show(context);
    if (!context.mounted) return;
    if (takeTour != true) {
      await OnboardingStore.markAllTipsSeen();
      return;
    }
    tipsOn = true;
  } else if (prompt == TutorialPromptKind.whatsNew) {
    if (!context.mounted) return;
    final takeTour = await FirstVueWhatsNewDialog.show(context);
    if (!context.mounted) return;
    await OnboardingStore.markWhatsNewSeen();
    if (takeTour != true) {
      await OnboardingStore.markAllTipsSeen();
      return;
    }
    tipsOn = true;
  }

  if (!tipsOn && !await OnboardingStore.tipsEnabled()) return;
  if (!context.mounted) return;

  final section = initialSection ?? TutorialSection.vue;
  await maybeShowSectionTip(context, section);
}

/// Replay from Settings — tips appear again as you visit each section.
Future<void> showOnboardingTourReplay(BuildContext context) async {
  await OnboardingStore.resetTips();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (_) => const _TutorialReplayDialog(),
  );
}

// ─── Welcome ─────────────────────────────────────────────────────────────────

class FirstVueWelcomeDialog extends StatelessWidget {
  const FirstVueWelcomeDialog({super.key});

  /// Returns `true` when the user wants tips, `false`/`null` to explore later.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstVueWelcomeDialog(),
    );
  }

  Future<void> _finish(BuildContext context, {required bool takeTour}) async {
    await OnboardingStore.markWelcomeSeen();
    if (context.mounted) Navigator.pop(context, takeTour);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FirstVueEmblem(size: 56),
              const SizedBox(height: 18),
              const Text(
                'Welcome to FirstVue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: _kGold,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'where we stay connected',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: _kTeal,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Discover events near you, meet people in your city, '
                'follow communities, and celebrate local moments together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(
                'We\'ll show short tips as you open each section — Home, VUE & '
                'LIVE, Feeds, Explore, Messages, and Settings — not all at once.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kGold, height: 1.4, fontSize: 13.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _finish(context, takeTour: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Yes — show me around'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _finish(context, takeTour: false),
                child: const Text(
                  'Maybe later — I\'ll explore',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── What's new (after updates) ──────────────────────────────────────────────

class FirstVueWhatsNewDialog extends StatelessWidget {
  const FirstVueWhatsNewDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstVueWhatsNewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FirstVueEmblem(size: 56),
              const SizedBox(height: 18),
              const Text(
                'What\'s new',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: _kGold,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A quicker tour of FirstVue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: _kTeal,
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'We added short tips that appear when you open each section — '
                'Home, VUE & LIVE, Feeds, Explore, Messages, and Settings — '
                'so new updates are easier to find.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Show me the tips'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Not now',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialReplayDialog extends StatelessWidget {
  const _TutorialReplayDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tips are on again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: _kGold,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Open Home, VUE, Feeds, Explore, Messages, or Settings — '
                'a short tip will point out that section when you get there.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
