import 'package:flutter/material.dart';

import '../services/onboarding_store.dart';
import 'tutorial_targets.dart';

const _kDialogBg = Color(0xFF10151B);
const _kGold = Color(0xFFD8B56A);
const _kTeal = Color(0xFF3DD9C9);

class _TipContent {
  final String title;
  final String body;
  final GlobalKey? Function() target;

  const _TipContent({
    required this.title,
    required this.body,
    required this.target,
  });
}

_TipContent _contentFor(TutorialSection section) {
  return switch (section) {
    TutorialSection.home => _TipContent(
        title: 'Home',
        body:
            'Your discovery hub — trending events, communities, and local picks. '
            'Browse what\'s happening here. For live activity nearby, open VUE '
            'and switch to LIVE.',
        target: () => TutorialTargets.homeNav,
      ),
    TutorialSection.vue => _TipContent(
        title: 'VUE & LIVE',
        body:
            'VUE is a swipe feed of local moments. LIVE is a live map of what\'s '
            'happening around you right now — different from Home discovery.',
        target: () {
          if (TutorialTargets.vueLiveSwitch.currentContext != null) {
            return TutorialTargets.vueLiveSwitch;
          }
          return TutorialTargets.vueNav;
        },
      ),
    TutorialSection.feeds => _TipContent(
        title: 'Feeds',
        body:
            'Updates from people, businesses, communities, and groups you follow. '
            'Use the Communities and Groups tabs to browse hubs and join in.',
        target: () => TutorialTargets.feedsTabs,
      ),
    TutorialSection.explore => _TipContent(
        title: 'Explore',
        body:
            'Find People, Businesses, Events, Communities, and Groups. '
            'Open Communities or Groups to discover hubs — or create your own.',
        target: () => TutorialTargets.exploreSections,
      ),
    TutorialSection.messages => _TipContent(
        title: 'Messages',
        body:
            'Chat with people, businesses, and event hosts. Messages is for DMs; '
            'Events holds gathering conversations.',
        target: () => TutorialTargets.messagesTabs,
      ),
    TutorialSection.settings => _TipContent(
        title: 'Business & monetization',
        body:
            'Get verified → Business Owner to claim or add your business. '
            'Monetization & Plans is where growth plans, boosts, and creator '
            'earnings live.',
        target: () => TutorialTargets.settingsVerified,
      ),
  };
}

bool _tipShowing = false;

/// Shows a short spotlight tip for [section] once, when the user visits it.
Future<void> maybeShowSectionTip(
  BuildContext context,
  TutorialSection section, {
  GlobalKey? targetKey,
}) async {
  if (_tipShowing) return;
  if (!await OnboardingStore.shouldShowTip(section)) return;
  if (!context.mounted) return;

  // Wait a frame so tab/screen layout (and keys) are ready.
  await Future<void>.delayed(const Duration(milliseconds: 280));
  if (!context.mounted) return;
  if (!await OnboardingStore.shouldShowTip(section)) return;
  if (_tipShowing || !context.mounted) return;

  final content = _contentFor(section);
  final key = targetKey ?? content.target();

  _tipShowing = true;
  try {
    final action = await showGeneralDialog<_TipAction>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Tutorial tip',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secondary) {
        return _SectionTipOverlay(
          section: section,
          title: content.title,
          body: content.body,
          targetKey: key,
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );

    if (action == _TipAction.skipAll) {
      await OnboardingStore.markAllTipsSeen();
    } else {
      await OnboardingStore.markTipSeen(section);
    }
  } finally {
    _tipShowing = false;
  }
}

enum _TipAction { gotIt, skipAll }

class _SectionTipOverlay extends StatelessWidget {
  final TutorialSection section;
  final String title;
  final String body;
  final GlobalKey? targetKey;

  const _SectionTipOverlay({
    required this.section,
    required this.title,
    required this.body,
    this.targetKey,
  });

  Rect? _targetRect(BuildContext context) {
    final ctx = targetKey?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final target = _targetRect(context);
    final hole = target == null
        ? null
        : Rect.fromLTRB(
            (target.left - 8).clamp(8.0, size.width - 8),
            (target.top - 8).clamp(padding.top + 4, size.height - 8),
            (target.right + 8).clamp(8.0, size.width - 8),
            (target.bottom + 8).clamp(padding.top + 4, size.height - 8),
          );

    final tipTop = hole == null
        ? size.height * 0.28
        : hole.center.dy > size.height * 0.45
            ? (hole.top - 12 - 200).clamp(
                padding.top + 12.0,
                size.height - 220,
              )
            : (hole.bottom + 14).clamp(
                padding.top + 12.0,
                size.height - 220,
              );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpotlightPainter(hole: hole),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: tipTop,
            child: _TipCard(
              title: title,
              body: body,
              onGotIt: () => Navigator.pop(context, _TipAction.gotIt),
              onSkipAll: () => Navigator.pop(context, _TipAction.skipAll),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onGotIt;
  final VoidCallback onSkipAll;

  const _TipCard({
    required this.title,
    required this.body,
    required this.onGotIt,
    required this.onSkipAll,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _kDialogBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'CormorantGaramond',
                color: _kGold,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton(
                  onPressed: onSkipAll,
                  child: const Text(
                    'Skip tips',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onGotIt,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;

  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.62);
    if (hole == null) {
      canvas.drawRect(Offset.zero & size, overlay);
      return;
    }

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(14)),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final border = Paint()
      ..color = _kTeal.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole!, const Radius.circular(14)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}
