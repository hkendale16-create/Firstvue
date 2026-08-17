import 'package:flutter/material.dart';

import '../models/growth_prompt.dart';
import '../models/publish_destination.dart';
import '../navigation/entity_navigation.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/create_post_screen.dart';
import '../screens/event_planner_screen.dart';
import '../screens/people_to_follow_screen.dart';
import '../screens/story_composer_screen.dart';
import '../screens/things_to_do_screen.dart';
import '../services/growth_prompt_service.dart';
import '../services/invite_friends_service.dart';
import '../services/product_analytics_service.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_share_sheet.dart';

/// Routes growth CTAs into existing FirstVue features.
class GrowthPromptActions {
  GrowthPromptActions._();

  static Future<void> run(
    BuildContext context,
    GrowthPromptSpec spec, {
    bool secondary = false,
  }) async {
    await GrowthPromptService.markClicked(spec);
    if (!context.mounted) return;

    if (secondary && spec.secondaryActionLabel == 'Create Event') {
      await openCreateEvent(context);
      return;
    }

    switch (spec.type) {
      case GrowthPromptType.createPost:
      case GrowthPromptType.uploadPhoto:
        await openComposer(context);
      case GrowthPromptType.uploadVideo:
        await openComposer(
          context,
          destination: spec.context == GrowthPromptContext.vue
              ? PublishDestination.vue
              : null,
        );
      case GrowthPromptType.createStory:
        await openStory(context);
      case GrowthPromptType.exploreEvents:
      case GrowthPromptType.discoverNearby:
        await openEvents(context);
      case GrowthPromptType.followPeople:
        await openPeople(context);
      case GrowthPromptType.joinCommunity:
        await EntityNavigation.openCommunitiesBrowse(
          context,
          allowCreate: true,
        );
      case GrowthPromptType.inviteFriends:
      case GrowthPromptType.shareApp:
        await openInvite(context);
    }
  }

  static Future<void> openComposer(
    BuildContext context, {
    PublishDestination? destination,
  }) {
    return Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CreatePostScreen(initialDestination: destination),
      ),
    );
  }

  static Future<void> openStory(BuildContext context) {
    return Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const StoryComposerScreen()),
    );
  }

  static Future<void> openEvents(BuildContext context) {
    ProductAnalyticsService.recordEvent(
      'event_explored',
      screen: 'growth',
    );
    return Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const ThingsToDoScreen()),
    );
  }

  static Future<void> openCreateEvent(BuildContext context) {
    return Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const EventPlannerScreen()),
    );
  }

  static Future<void> openPeople(BuildContext context) {
    return Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const PeopleToFollowScreen()),
    );
  }

  static Future<void> openInvite(BuildContext context) async {
    await ProductAnalyticsService.recordEvent(
      'invite_started',
      screen: 'invite',
    );
    final payload = await InviteFriendsService.invitePayload();
    if (!context.mounted) return;
    await FirstVueShareSheet.show(
      context,
      payload: payload,
      onAction: (_) {
        ProductAnalyticsService.recordEvent(
          'invite_shared',
          screen: 'invite',
        );
        GrowthPromptService.markCompleted(GrowthCompletedAction.inviteFriends);
      },
    );
  }
}

/// Reusable growth prompt. Screens pass type/copy; this owns layout + dismiss.
class GrowthPrompt extends StatelessWidget {
  final GrowthPromptSpec spec;
  final GrowthPromptVariant variant;
  final VoidCallback? onAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onDismiss;

  const GrowthPrompt({
    super.key,
    required this.spec,
    this.variant = GrowthPromptVariant.card,
    this.onAction,
    this.onSecondaryAction,
    this.onDismiss,
  });

  Future<void> _action(BuildContext context) async {
    if (onAction != null) {
      onAction!();
      return;
    }
    await GrowthPromptActions.run(context, spec);
  }

  Future<void> _secondary(BuildContext context) async {
    if (onSecondaryAction != null) {
      onSecondaryAction!();
      return;
    }
    await GrowthPromptActions.run(context, spec, secondary: true);
  }

  Future<void> _dismiss() async {
    await GrowthPromptService.dismiss(spec.type);
    onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      GrowthPromptVariant.sheet => _SheetBody(
          spec: spec,
          onAction: () => _action(context),
          onDismiss: _dismiss,
        ),
      GrowthPromptVariant.empty => _EmptyBody(
          spec: spec,
          onAction: () => _action(context),
          onSecondary: spec.secondaryActionLabel == null
              ? null
              : () => _secondary(context),
        ),
      GrowthPromptVariant.composer => _ComposerBody(
          spec: spec,
          onAction: () => _action(context),
          onDismiss: onDismiss == null ? null : _dismiss,
        ),
      GrowthPromptVariant.banner ||
      GrowthPromptVariant.card => _CardBody(
          spec: spec,
          compact: variant == GrowthPromptVariant.banner,
          onAction: () => _action(context),
          onSecondary: spec.secondaryActionLabel == null
              ? null
              : () => _secondary(context),
          onDismiss: onDismiss == null ? null : _dismiss,
        ),
    };
  }
}

class _CardBody extends StatelessWidget {
  final GrowthPromptSpec spec;
  final bool compact;
  final VoidCallback onAction;
  final VoidCallback? onSecondary;
  final VoidCallback? onDismiss;

  const _CardBody({
    required this.spec,
    required this.compact,
    required this.onAction,
    this.onSecondary,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: fv.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    spec.title,
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      color: fv.primaryText,
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Dismiss',
                    icon: Icon(Icons.close, size: 18, color: fv.tertiaryText),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              spec.description,
              style: TextStyle(
                color: fv.secondaryText,
                height: 1.35,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: const Color(0xFF1A1520),
                  ),
                  child: Text(spec.actionLabel),
                ),
                if (onSecondary != null && spec.secondaryActionLabel != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(spec.secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final GrowthPromptSpec spec;
  final VoidCallback onAction;
  final VoidCallback? onSecondary;

  const _EmptyBody({
    required this.spec,
    required this.onAction,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          Text(
            spec.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            spec.description,
            textAlign: TextAlign.center,
            style: TextStyle(color: fv.secondaryText, height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: const Color(0xFF1A1520),
                ),
                child: Text(spec.actionLabel),
              ),
              if (onSecondary != null && spec.secondaryActionLabel != null)
                OutlinedButton(
                  onPressed: onSecondary,
                  child: Text(spec.secondaryActionLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerBody extends StatelessWidget {
  final GrowthPromptSpec spec;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  const _ComposerBody({
    required this.spec,
    required this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: fv.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: fv.elevatedSurface,
                    child: Icon(Icons.person, color: fv.mutedIcon, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "What's happening?",
                      style: TextStyle(color: fv.tertiaryText, fontSize: 14),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      onPressed: onDismiss,
                      tooltip: 'Dismiss',
                      icon: Icon(Icons.close, size: 18, color: fv.tertiaryText),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  _Chip(icon: Icons.photo_library_outlined, label: 'Photo'),
                  _Chip(icon: Icons.videocam_outlined, label: 'Video'),
                  _Chip(icon: Icons.event_outlined, label: 'Event'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: FirstVueColors.gold),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: context.fv.secondaryText,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _SheetBody extends StatelessWidget {
  final GrowthPromptSpec spec;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  const _SheetBody({
    required this.spec,
    required this.onAction,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: fv.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              spec.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: fv.primaryText,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              spec.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fv.secondaryText,
                height: 1.4,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: const Color(0xFF1A1520),
                ),
                child: Text(spec.actionLabel),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: Text('Not now', style: TextStyle(color: fv.tertiaryText)),
            ),
          ],
        ),
      ),
    );
  }
}
