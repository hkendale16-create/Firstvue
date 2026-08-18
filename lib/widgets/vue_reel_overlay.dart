import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/hashtag_posts_screen.dart';
import '../services/community_news_service.dart';
import '../services/discovery_feed_service.dart';
import '../services/post_metadata_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/compact_count.dart';
import 'entity_follow_button.dart';
import 'network_photo.dart';
import 'social_rich_text.dart';
import 'vue_trending_badge.dart';

/// Right-side social controls + lower caption overlay for the VUE reel viewer.
class VueReelOverlay extends StatelessWidget {
  final DiscoveryFeedItem item;
  final bool captionExpanded;
  final VoidCallback onToggleCaption;
  final VoidCallback onOpenProfile;
  final VoidCallback onLike;
  final ValueChanged<PostReactionType>? onReaction;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onMore;
  final VoidCallback onOpenDetails;

  const VueReelOverlay({
    super.key,
    required this.item,
    required this.captionExpanded,
    required this.onToggleCaption,
    required this.onOpenProfile,
    required this.onLike,
    this.onReaction,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onMore,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                ],
                stops: [0, 0.18, 0.52, 1],
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 118,
          child: _VueReelActionRail(
            item: item,
            onLike: onLike,
            onReaction: onReaction,
            onComment: onComment,
            onShare: onShare,
            onSave: onSave,
            onMore: onMore,
          ),
        ),
        Positioned(
          left: 14,
          right: 78,
          bottom: 18,
          child: _VueReelCaption(
            item: item,
            expanded: captionExpanded,
            onToggleCaption: onToggleCaption,
            onOpenProfile: onOpenProfile,
            onOpenDetails: onOpenDetails,
          ),
        ),
      ],
    );
  }
}

class _VueReelActionRail extends StatelessWidget {
  final DiscoveryFeedItem item;
  final VoidCallback onLike;
  final ValueChanged<PostReactionType>? onReaction;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onMore;

  const _VueReelActionRail({
    required this.item,
    required this.onLike,
    this.onReaction,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final liked = item.userHasLiked;
    final reaction = PostReactionType.tryParse(item.myReactionType);
    return StopPropagation(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RailButton(
            key: const Key('vue-reel-like'),
            icon: liked
                ? (reaction?.icon ?? Icons.favorite_rounded)
                : Icons.favorite_border_rounded,
            color: liked
                ? (reaction?.color ?? const Color(0xFFFF6B8A))
                : Colors.white,
            label: item.likesCount > 0 ? compactCount(item.likesCount) : null,
            onTap: onLike,
            onLongPress: onReaction == null
                ? null
                : () => _pickReaction(context, onReaction!),
          ),
          _RailButton(
            key: const Key('vue-reel-comment'),
            icon: Icons.mode_comment_outlined,
            label: item.commentsCount > 0
                ? compactCount(item.commentsCount)
                : null,
            onTap: onComment,
          ),
          _RailButton(
            key: const Key('vue-reel-share'),
            icon: Icons.ios_share_rounded,
            label: item.sharesCount > 0 ? compactCount(item.sharesCount) : null,
            onTap: onShare,
          ),
          _RailButton(
            key: const Key('vue-reel-save'),
            icon: item.userHasSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: item.userHasSaved ? FirstVueColors.gold : Colors.white,
            label: item.savesCount > 0 ? compactCount(item.savesCount) : null,
            onTap: onSave,
          ),
          _RailButton(
            key: const Key('vue-reel-more'),
            icon: Icons.more_horiz_rounded,
            onTap: onMore,
          ),
        ],
      ),
    );
  }

  Future<void> _pickReaction(
    BuildContext context,
    ValueChanged<PostReactionType> onSelected,
  ) async {
    final selected = await showModalBottomSheet<PostReactionType>(
      context: context,
      backgroundColor: const Color(0xEE12161E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final type in PostReactionType.values)
                  InkWell(
                    onTap: () => Navigator.pop(context, type),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(type.icon, color: type.color, size: 28),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) onSelected(selected);
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RailButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.color = Colors.white,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              Icon(icon, color: color, size: 30, shadows: const [
                Shadow(color: Colors.black87, blurRadius: 8),
              ]),
              if (label != null) ...[
                const SizedBox(height: 2),
                Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
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

class _VueReelCaption extends StatelessWidget {
  final DiscoveryFeedItem item;
  final bool expanded;
  final VoidCallback onToggleCaption;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDetails;

  const _VueReelCaption({
    required this.item,
    required this.expanded,
    required this.onToggleCaption,
    required this.onOpenProfile,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final caption = item.caption.trim();
    final tags = PostMetadataService.parse(caption).hashtags;
    final long = caption.length > 90 || caption.split('\n').length > 2;
    final preview = long && !expanded
        ? '${caption.substring(0, caption.length.clamp(0, 90)).trim()}…'
        : caption;

    return StopPropagation(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.trendingRank != null && item.trendingRank! > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VueTrendingBadge(rank: item.trendingRank!),
            ),
          GestureDetector(
            onTap: onOpenProfile,
            child: Row(
              children: [
                NetworkCircleAvatar(
                  imageUrl: item.avatarUrl != null &&
                          item.avatarUrl!.startsWith('http')
                      ? item.avatarUrl
                      : null,
                  radius: 16,
                  backgroundColor: const Color(0xAA1C1829),
                  placeholder: Icon(
                    item.isMember
                        ? Icons.person_rounded
                        : Icons.storefront_rounded,
                    size: 16,
                    color: FirstVueColors.gold,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.displayHandle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                    ),
                  ),
                ),
                if (item.verified) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.verified,
                    color: FirstVueColors.gold,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 8),
            SocialRichText(
              text: expanded ? caption : preview,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
            if (long)
              GestureDetector(
                onTap: onToggleCaption,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    expanded ? 'less' : 'more',
                    style: TextStyle(
                      color: FirstVueColors.gold.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in tags.take(expanded ? tags.length : 4))
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => HashtagPostsScreen(tag: tag),
                        ),
                      );
                    },
                    child: Text(
                      '#$tag',
                      style: const TextStyle(
                        color: FirstVueColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onOpenDetails,
            child: Text(
              _metricsLine(item),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _metricsLine(DiscoveryFeedItem item) {
    final parts = <String>[
      '${compactCount(item.viewsCount)} views',
      if (item.isVideo) '${compactCount(item.playsCount)} plays',
    ];
    return parts.join(' · ');
  }
}
