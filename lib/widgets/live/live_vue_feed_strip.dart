import 'package:flutter/material.dart';

import '../../services/discovery_feed_service.dart';
import '../../theme/firstvue_theme.dart';
import '../../theme/live_tokens.dart';
import '../network_photo.dart';

class LiveVueFeedStrip extends StatelessWidget {
  final List<DiscoveryFeedItem> items;
  final ValueChanged<DiscoveryFeedItem>? onOpen;

  const LiveVueFeedStrip({
    super.key,
    required this.items,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(
          'No recent VUEs nearby yet.',
          style: TextStyle(color: fv.secondaryText, fontSize: 13),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      itemCount: items.length.clamp(0, 6),
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        return _LiveVueRow(item: item, onTap: () => onOpen?.call(item));
      },
    );
  }
}

class _LiveVueRow extends StatelessWidget {
  final DiscoveryFeedItem item;
  final VoidCallback? onTap;

  const _LiveVueRow({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final name = item.isMember
        ? (item.ownerName.isNotEmpty ? item.ownerName : 'Member')
        : (item.businessName.isNotEmpty ? item.businessName : item.ownerName);
    final location = item.locationLabel?.trim();
    final thumb = (item.thumbnailUrl?.isNotEmpty == true)
        ? item.thumbnailUrl!
        : item.mediaUrl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: LiveTokens.elevated,
                backgroundImage:
                    item.avatarUrl != null && item.avatarUrl!.startsWith('http')
                        ? NetworkImage(item.avatarUrl!)
                        : null,
                child: item.avatarUrl == null || !item.avatarUrl!.startsWith('http')
                    ? Icon(Icons.person, size: 14, color: fv.mutedIcon)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (location != null && location.isNotEmpty)
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: LiveTokens.bronzeSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb.startsWith('http'))
                    NetworkPhoto(url: thumb, fit: BoxFit.cover)
                  else
                    ColoredBox(color: LiveTokens.surface),
                  if (item.isVideo)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (item.caption.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.caption.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fv.primaryText, fontSize: 13, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
