import 'package:flutter/material.dart';

import '../services/onboarding_store.dart';

class FirstVueWelcomeDialog extends StatelessWidget {
  final VoidCallback onContinue;

  const FirstVueWelcomeDialog({super.key, required this.onContinue});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FirstVueWelcomeDialog(
        onContinue: () async {
          await OnboardingStore.markWelcomeSeen();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF10151B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              color: Color(0xFFD8B56A),
              size: 42,
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to FirstVue',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: Color(0xFFD8B56A),
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'FirstVue is a new app — we are growing every day. '
              'Discover verified businesses, explore Vue, save favorites, '
              'and connect directly with owners.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your support while we grow means everything. '
              'Thank you for being here early.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFD8B56A), height: 1.4),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD8B56A),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirstVueTutorialDialog extends StatefulWidget {
  const FirstVueTutorialDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FirstVueTutorialDialog(),
    );
  }

  @override
  State<FirstVueTutorialDialog> createState() => _FirstVueTutorialDialogState();
}

class _FirstVueTutorialDialogState extends State<FirstVueTutorialDialog> {
  final _pageController = PageController();
  int _page = 0;

  static const _steps = [
    (
      icon: Icons.home_rounded,
      title: 'Home & Explore',
      body:
          'Browse categories — barbers, beauty, restaurants, things to do, and more. '
          'Use Ask FirstVue AI search to describe what you need.',
    ),
    (
      icon: Icons.smart_display_rounded,
      title: 'Vue Feed',
      body:
          'Swipe through business moments. Spark what you love, save to Collection, '
          'Route a link to friends, and leave comments.',
    ),
    (
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Messages',
      body:
          'Message business owners directly from verified profiles. '
          'Find all conversations under Profile → Messages.',
    ),
    (
      icon: Icons.bookmark_rounded,
      title: 'Saved & Profile',
      body:
          'Save businesses you want to revisit. Sign in from Profile to post reviews, '
          'manage your business, or become a verified professional.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingStore.markTutorialCompleted();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _steps.length - 1;
    return Dialog(
      backgroundColor: const Color(0xFF10151B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        height: 360,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                    child: Column(
                      children: [
                        Icon(step.icon, color: const Color(0xFFD8B56A), size: 44),
                        const SizedBox(height: 18),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'CormorantGaramond',
                            color: Color(0xFFD8B56A),
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          step.body,
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
                _steps.length,
                (index) => Container(
                  width: index == _page ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? const Color(0xFFD8B56A)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
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
                    const Spacer(),
                  const Spacer(),
                  FilledButton(
                    onPressed: isLast
                        ? _finish
                        : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD8B56A),
                      foregroundColor: Colors.black,
                    ),
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showFirstLaunchExperience(BuildContext context) async {
  if (await OnboardingStore.shouldShowWelcome()) {
    if (!context.mounted) return;
    await FirstVueWelcomeDialog.show(context);
  }
  if (await OnboardingStore.shouldShowTutorial()) {
    if (!context.mounted) return;
    await FirstVueTutorialDialog.show(context);
  }
}
