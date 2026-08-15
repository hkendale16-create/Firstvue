import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/join_firstvue_screen.dart';
import '../services/onboarding_store.dart';
import 'firstvue_emblem.dart';

const _kDialogBg = Color(0xFF10151B);
const _kGold = Color(0xFFD8B56A);
const _kTeal = Color(0xFF3DD9C9);

/// First signed-in visit: welcome, then an optional tour chooser.
Future<void> showFirstLaunchExperience(BuildContext context) async {
  if (await OnboardingStore.shouldShowWelcome()) {
    if (!context.mounted) return;
    final takeTour = await FirstVueWelcomeDialog.show(context);
    if (!context.mounted) return;
    if (takeTour != true) {
      await OnboardingStore.markTutorialCompleted();
      return;
    }
  }

  if (await OnboardingStore.shouldShowTutorial()) {
    if (!context.mounted) return;
    await FirstVueTourChooserDialog.show(context);
  }
}

/// Replay from Settings — always offers the chooser.
Future<void> showOnboardingTourReplay(BuildContext context) async {
  await FirstVueTourChooserDialog.show(context, forceShow: true);
}

// ─── Welcome ─────────────────────────────────────────────────────────────────

class FirstVueWelcomeDialog extends StatelessWidget {
  const FirstVueWelcomeDialog({super.key});

  /// Returns `true` when the user wants the tour, `false`/`null` to explore later.
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
                'follow communities, and celebrate local moments together. '
                'FirstVue is where nights out, gatherings, and the people '
                'behind them stay close.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 12),
              const Text(
                'Want a quick tour of each section — or how to open a '
                'business so others can find your events and connect with you?',
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

// ─── Tour chooser ────────────────────────────────────────────────────────────

enum _TourPath { sections, business, skip }

class FirstVueTourChooserDialog extends StatelessWidget {
  const FirstVueTourChooserDialog({super.key});

  static Future<void> show(
    BuildContext hostContext, {
    bool forceShow = false,
  }) async {
    final path = await showDialog<_TourPath>(
      context: hostContext,
      barrierDismissible: false,
      builder: (_) => const FirstVueTourChooserDialog(),
    );

    if (!hostContext.mounted) return;

    switch (path) {
      case _TourPath.sections:
        final openBusiness = await FirstVueSectionTutorialDialog.show(
          hostContext,
        );
        if (!hostContext.mounted) return;
        if (openBusiness == true) {
          await FirstVueBusinessEntityTutorialDialog.show(hostContext);
        }
      case _TourPath.business:
        await FirstVueBusinessEntityTutorialDialog.show(hostContext);
      case _TourPath.skip:
      case null:
        if (!forceShow) await OnboardingStore.markTutorialCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'How do you want to start?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  color: _kGold,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick a short walkthrough — both keep people and events at the center.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 20),
              _TourChoiceCard(
                icon: Icons.explore_outlined,
                title: 'Tour each section',
                body:
                    'Home, Feeds, VUE, Explore & Profile — how you find events '
                    'and stay connected with people.',
                accent: _kTeal,
                onTap: () => Navigator.pop(context, _TourPath.sections),
              ),
              const SizedBox(height: 12),
              _TourChoiceCard(
                icon: Icons.storefront_outlined,
                title: 'Open a business entity',
                body:
                    'See the steps to claim or add your business, get verified, '
                    'host events, and connect with your community.',
                accent: _kGold,
                onTap: () => Navigator.pop(context, _TourPath.business),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, _TourPath.skip),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TourChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final VoidCallback onTap;

  const _TourChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            color: Colors.white.withValues(alpha: 0.04),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared step page model ──────────────────────────────────────────────────

typedef _TutorialStep = ({IconData icon, String title, String body});

enum _PagerResult { finished, skipped, openBusiness, startVerified }

class _TutorialPagerDialog extends StatefulWidget {
  final String progressLabel;
  final List<_TutorialStep> steps;
  final String finishLabel;
  final String? secondaryLabel;
  final _PagerResult secondaryResult;

  const _TutorialPagerDialog({
    required this.progressLabel,
    required this.steps,
    required this.finishLabel,
    this.secondaryLabel,
    this.secondaryResult = _PagerResult.finished,
  });

  @override
  State<_TutorialPagerDialog> createState() => _TutorialPagerDialogState();
}

class _TutorialPagerDialogState extends State<_TutorialPagerDialog> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == widget.steps.length - 1;
    return Dialog(
      backgroundColor: _kDialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Text(
                      '${widget.progressLabel} · ${_page + 1}/${widget.steps.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _PagerResult.skipped),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.steps.length,
                  onPageChanged: (index) => setState(() => _page = index),
                  itemBuilder: (context, index) {
                    final s = widget.steps[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Column(
                        children: [
                          Icon(s.icon, color: _kGold, size: 44),
                          const SizedBox(height: 16),
                          Text(
                            s.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'CormorantGaramond',
                              color: _kGold,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            s.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: index == _page ? 18 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == _page ? _kGold : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_page > 0)
                          TextButton(
                            onPressed: () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            ),
                            child: const Text('Back'),
                          )
                        else
                          const SizedBox(width: 64),
                        const Spacer(),
                        FilledButton(
                          onPressed: isLast
                              ? () => Navigator.pop(
                                  context,
                                  _PagerResult.finished,
                                )
                              : () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kGold,
                            foregroundColor: Colors.black,
                          ),
                          child: Text(isLast ? widget.finishLabel : 'Next'),
                        ),
                      ],
                    ),
                    if (isLast && widget.secondaryLabel != null) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.pop(
                          context,
                          widget.secondaryResult,
                        ),
                        child: Text(
                          widget.secondaryLabel!,
                          style: const TextStyle(color: _kTeal),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section tutorial ────────────────────────────────────────────────────────

class FirstVueSectionTutorialDialog extends StatelessWidget {
  const FirstVueSectionTutorialDialog({super.key});

  static const _steps = <_TutorialStep>[
    (
      icon: Icons.home_rounded,
      title: 'Home',
      body:
          'Your starting place for what\'s happening. Browse Trending, Events, '
          'Communities, and more — then tap into nights out, gatherings, and '
          'people worth meeting.',
    ),
    (
      icon: Icons.dynamic_feed_rounded,
      title: 'Feeds',
      body:
          'Stay in the loop with the people, businesses, and communities you follow. '
          'See updates from events you care about — where we stay connected day to day.',
    ),
    (
      icon: Icons.smart_display_rounded,
      title: 'VUE',
      body:
          'Swipe through live moments from local life — event energy, shop vibes, '
          'and faces in the crowd. Spark what you love, save it, and share the night.',
    ),
    (
      icon: Icons.explore_rounded,
      title: 'Explore',
      body:
          'Find People, Businesses, Events, Things to Do, Communities, and Groups. '
          'RSVP, follow organizers, and discover who\'s bringing people together near you.',
    ),
    (
      icon: Icons.person_outline_rounded,
      title: 'Profile & Messages',
      body:
          'Your hub to save favorites, manage follows, and message hosts or owners. '
          'From Settings you can get verified, plan events, or open a business entity.',
    ),
  ];

  /// Returns `true` if the user asked to continue into the business walkthrough.
  static Future<bool?> show(BuildContext hostContext) async {
    final result = await showDialog<_PagerResult>(
      context: hostContext,
      barrierDismissible: false,
      builder: (_) => const FirstVueSectionTutorialDialog(),
    );

    if (result == _PagerResult.openBusiness) return true;

    await OnboardingStore.markTutorialCompleted();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return const _TutorialPagerDialog(
      progressLabel: 'App tour',
      steps: _steps,
      finishLabel: 'Got it',
      secondaryLabel: 'Also show business steps',
      secondaryResult: _PagerResult.openBusiness,
    );
  }
}

// ─── Business entity tutorial ────────────────────────────────────────────────

class FirstVueBusinessEntityTutorialDialog extends StatelessWidget {
  const FirstVueBusinessEntityTutorialDialog({super.key});

  static const _steps = <_TutorialStep>[
    (
      icon: Icons.storefront_outlined,
      title: 'Your place to gather',
      body:
          'A business entity on FirstVue is your verified home base — so people '
          'can find your space, follow what\'s next, and show up for the events '
          'you host. This is where we stay connected with your community.',
    ),
    (
      icon: Icons.how_to_reg_outlined,
      title: 'Step 1 · Get verified',
      body:
          'Open Profile → Settings → Get verified → Business Owner. '
          'You\'ll land in Business Tools. (Professionals and event organizers '
          'have their own paths if that fits you better.)',
    ),
    (
      icon: Icons.add_business_outlined,
      title: 'Step 2 · Claim or add',
      body:
          'Claim a listed business if you already appear in FirstVue, or add an '
          'unlisted one with name, industry, type, and services. Nothing goes '
          'public until FirstVue approves it.',
    ),
    (
      icon: Icons.event_available_outlined,
      title: 'Step 3 · Connect & host',
      body:
          'Once approved, polish your profile, post VUE moments, message guests, '
          'and use Event Planner to create gatherings. People can follow, RSVP, '
          'and keep your nights on their radar.',
    ),
    (
      icon: Icons.celebration_outlined,
      title: 'What it unlocks',
      body:
          'A public, verified presence people can trust — discoverable in Explore '
          'and Home Events, ready for shoutouts, follows, and real connections. '
          'You bring the people; FirstVue helps you stay linked.',
    ),
  ];

  static Future<void> show(BuildContext hostContext) async {
    final result = await showDialog<_PagerResult>(
      context: hostContext,
      barrierDismissible: false,
      builder: (_) => const FirstVueBusinessEntityTutorialDialog(),
    );

    await OnboardingStore.markTutorialCompleted();
    if (!hostContext.mounted) return;

    if (result == _PagerResult.startVerified) {
      await Navigator.push(
        hostContext,
        FirstVuePageRoute(builder: (_) => const JoinFirstVueScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _TutorialPagerDialog(
      progressLabel: 'Business entity',
      steps: _steps,
      finishLabel: 'I\'m ready',
      secondaryLabel: 'Start Get verified',
      secondaryResult: _PagerResult.startVerified,
    );
  }
}
