import 'package:flutter/material.dart';

import '../navigation/entity_navigation.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/shoutout_service.dart';
import '../theme/firstvue_theme.dart';

class ShoutoutCard extends StatelessWidget {
  final Shoutout shoutout;
  final bool compact;

  const ShoutoutCard({
    super.key,
    required this.shoutout,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GestureDetector(
                onTap: () => openMemberProfile(
                  context,
                  profileId: shoutout.creatorId,
                  displayName: shoutout.creatorName,
                ),
                child: Text(
                  shoutout.creatorHandle,
                  style: const TextStyle(
                    color: FirstVueColors.teal,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                ' gave a shoutout to ',
                style: TextStyle(color: context.fv.secondaryText, fontSize: 13),
              ),
              GestureDetector(
                onTap: () => EntityNavigation.openShoutoutTarget(
                  context,
                  type: shoutout.targetType,
                  id: shoutout.targetId,
                ),
                child: Text(
                  shoutout.targetName,
                  style: const TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            shoutout.targetType.label +
                (shoutout.targetSubtitle == null
                    ? ''
                    : ' · ${shoutout.targetSubtitle}'),
            style: TextStyle(
              color: context.fv.tertiaryText,
              fontSize: 11,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            shoutout.message,
            style: TextStyle(color: context.fv.primaryText, height: 1.35),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                ShoutoutService.formatRelativeTime(shoutout.createdAt),
                style: TextStyle(
                  color: context.fv.tertiaryText,
                  fontSize: 11,
                ),
              ),
              if (shoutout.sparkCount > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '${shoutout.sparkCount} spark${shoutout.sparkCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: context.fv.tertiaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class ShoutoutsReceivedSection extends StatefulWidget {
  final ShoutoutTargetType targetType;
  final String targetId;
  final int refreshToken;
  final String title;

  const ShoutoutsReceivedSection({
    super.key,
    required this.targetType,
    required this.targetId,
    this.refreshToken = 0,
    this.title = 'SHOUTOUTS',
  });

  @override
  State<ShoutoutsReceivedSection> createState() =>
      _ShoutoutsReceivedSectionState();
}

class _ShoutoutsReceivedSectionState extends State<ShoutoutsReceivedSection> {
  late Future<List<Shoutout>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ShoutoutsReceivedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId ||
        oldWidget.targetType != widget.targetType ||
        oldWidget.refreshToken != widget.refreshToken) {
      _future = _load();
    }
  }

  Future<List<Shoutout>> _load() {
    return ShoutoutService.fetchForTarget(
      targetType: widget.targetType,
      targetId: widget.targetId,
      limit: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Shoutout>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Shoutout>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FirstVueColors.gold,
                ),
              ),
            ),
          );
        }
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              for (final shoutout in items)
                ShoutoutCard(shoutout: shoutout, compact: true),
            ],
          ),
        );
      },
    );
  }
}
