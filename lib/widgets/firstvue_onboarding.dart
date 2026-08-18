import 'package:flutter/material.dart';

import '../services/onboarding_store.dart';
import 'firstvue_emblem.dart';
import 'firstvue_section_tip.dart';

const _kDialogBg = Color(0xFF10151B);
const _kGold = Color(0xFFD8B56A);
const _kTeal = Color(0xFF3DD9C9);

/// Compact overview of what FirstVue covers, shown on the welcome dialog.
/// One job for new users: see what’s going on nearby.
class _WelcomeHighlights extends StatelessWidget {
  const _WelcomeHighlights();

  static const _items = <(IconData, String)>[
    (Icons.place_outlined, 'Nearby'),
    (Icons.nights_stay_outlined, 'Tonight'),
    (Icons.person_add_alt_1_outlined, 'Follow'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label) in _items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kTeal.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: _kTeal),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// First signed-in visit or post-update session: welcome / what's new, then tips.
Future<void> showFirstLaunchExperience(
  BuildContext context, {
  TutorialSection? initialSection,
  Future<void> Function()? afterWelcome,
}) async {
  var tipsOn = false;

  final prompt = await OnboardingStore.pendingPrompt();
  if (prompt == TutorialPromptKind.welcome) {
    if (!context.mounted) return;
    final takeTour = await FirstVueWelcomeDialog.show(context);
    if (!context.mounted) return;
    if (takeTour != true) {
      await OnboardingStore.markAllTipsSeen();
    } else {
      tipsOn = true;
    }
  } else if (prompt == TutorialPromptKind.whatsNew) {
    if (!context.mounted) return;
    final takeTour = await FirstVueWhatsNewDialog.show(context);
    if (!context.mounted) return;
    await OnboardingStore.markWhatsNewSeen();
    if (takeTour != true) {
      await OnboardingStore.markAllTipsSeen();
    } else {
      tipsOn = true;
    }
  }

  if (afterWelcome != null) {
    await afterWelcome();
    if (!context.mounted) return;
  }

  if (!tipsOn && !await OnboardingStore.tipsEnabled()) return;
  if (!context.mounted) return;

  final section = initialSection ?? TutorialSection.home;
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
          child: SingleChildScrollView(
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
                  'See what\'s going on near you — happening now, tonight, '
                  'and people worth following.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 10),
                const _WelcomeHighlights(),
                const SizedBox(height: 14),
                const Text(
                  'Set your city to fill Home with nearby events and follows. '
                  'Short tips can wait until you\'ve looked around.',
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
                    child: const Text('See what\'s nearby'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _finish(context, takeTour: false),
                  child: const Text(
                    'I\'ll explore on my own',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
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
                'Home, VUE & LIVE, Feeds, Explore, Messages, Settings, plus '
                'setting up your profile and choosing a theme — so new '
                'updates are easier to find.',
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
                'Open Home, VUE, Feeds, Explore, Messages, Settings, your '
                'profile, or Appearance — a short tip will point out that '
                'section when you get there.',
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
