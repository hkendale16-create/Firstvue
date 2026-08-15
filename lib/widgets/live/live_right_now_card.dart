import 'package:flutter/material.dart';

import '../../services/live_home_service.dart';
import '../../services/live_heat_service.dart';
import '../../theme/firstvue_theme.dart';
import '../../theme/live_tokens.dart';
import '../network_photo.dart';

class LiveRightNowCard extends StatelessWidget {
  final LiveRightNowItem item;
  final VoidCallback? onTap;

  const LiveRightNowCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final badge = _badgeFor(item.lifecycle);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LiveTokens.cardRadius),
      child: Ink(
        width: LiveTokens.cardWidth,
        height: LiveTokens.cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LiveTokens.cardRadius),
          color: LiveTokens.elevated,
          border: Border.all(color: fv.borderSubtle),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LiveTokens.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.imageUrl != null && item.imageUrl!.startsWith('http'))
                NetworkPhoto(url: item.imageUrl!, fit: BoxFit.cover)
              else
                ColoredBox(
                  color: LiveTokens.surface,
                  child: Icon(
                    Icons.event_outlined,
                    color: fv.mutedIcon,
                    size: 36,
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0xCC000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _StatusPill(
                  label: badge.label,
                  color: badge.color,
                  showDot: item.isLive,
                ),
              ),
              if (item.heatStatus != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _StatusPill(
                    label: switch (item.heatStatus!) {
                      LiveHeatStatus.hot => '🔥 HOT',
                      LiveHeatStatus.heatingUp => 'Heating Up',
                      LiveHeatStatus.active => 'Active',
                    },
                    color: switch (item.heatStatus!) {
                      LiveHeatStatus.hot => LiveTokens.liveEvent,
                      LiveHeatStatus.heatingUp => LiveTokens.happyHour,
                      LiveHeatStatus.active => LiveTokens.bronzeSoft,
                    },
                  ),
                ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item.isLive)
                      Text(
                        '● LIVE',
                        style: TextStyle(
                          color: LiveTokens.hereNow,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      )
                    else
                      Text(
                        LiveHomeService.lifecycleLabel(item.lifecycle),
                        style: TextStyle(
                          color: LiveTokens.bronzeSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _metaLine(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _metaLine(LiveRightNowItem item) {
    final parts = <String>[];
    final location = item.locationLabel?.trim();
    if (location != null && location.isNotEmpty) parts.add(location);
    if (item.goingCount != null) {
      parts.add('${item.goingCount} going');
    }
    if (parts.isEmpty) return 'Local event';
    return parts.join(' · ');
  }

  static ({String label, Color color}) _badgeFor(LiveLifecycleStatus status) {
    return switch (status) {
      LiveLifecycleStatus.live || LiveLifecycleStatus.endingSoon => (
          label: '🔥 LIVE',
          color: LiveTokens.liveEvent,
        ),
      LiveLifecycleStatus.startingSoon => (
          label: 'STARTING SOON',
          color: LiveTokens.market,
        ),
      LiveLifecycleStatus.upcoming => (
          label: 'UPCOMING',
          color: LiveTokens.bronze,
        ),
      LiveLifecycleStatus.ended => (
          label: 'ENDED',
          color: FirstVueColors.mutedIcon,
        ),
    };
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;

  const _StatusPill({
    required this.label,
    required this.color,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(LiveTokens.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.85)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
