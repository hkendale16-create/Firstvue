import 'package:flutter/material.dart';

import '../services/community_news_media_service.dart';
import '../services/community_news_service.dart';
import '../services/profile_activity_service.dart';
import '../theme/firstvue_theme.dart';
import 'feed_autoplay_video.dart';
import 'signed_media_viewer.dart';

enum CommunityNewsPostCardStyle { compact, timeline }

class CommunityNewsPostCard extends StatefulWidget {
  final CommunityNewsPost post;
  final VoidCallback? onTap;
  final VoidCallback? onSpark;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onDelete;
  final bool compact;
  final CommunityNewsPostCardStyle style;

  const CommunityNewsPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onSpark,
    this.onSave,
    this.onComment,
    this.onDelete,
    this.compact = false,
    this.style = CommunityNewsPostCardStyle.compact,
  });

  @override
  State<CommunityNewsPostCard> createState() => _CommunityNewsPostCardState();
}

class _CommunityNewsPostCardState extends State<CommunityNewsPostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _sparkFlashController;
  late Animation<double> _sparkFlash;

  CommunityNewsPost get post => widget.post;

  CommunityNewsPostCardStyle get _style => widget.compact
      ? CommunityNewsPostCardStyle.compact
      : widget.style;

  bool get _isTimeline => _style == CommunityNewsPostCardStyle.timeline;

  @override
  void initState() {
    super.initState();
    _sparkFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _sparkFlash = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sparkFlashController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _sparkFlashController.dispose();
    super.dispose();
  }

  void _handleDoubleTapSpark() {
    if (widget.onSpark == null) return;
    widget.onSpark!();
    _sparkFlashController.forward(from: 0);
  }

  String _authorInitial() {
    final trimmed = post.authorName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            _isTimeline ? 0 : 14,
            _isTimeline ? 0 : 14,
            _isTimeline ? 0 : 6,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: _isTimeline ? 20 : 18,
                backgroundColor: FirstVueColors.elevatedSurface,
                child: Text(
                  _authorInitial(),
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: _isTimeline ? 15 : 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.authorName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: _isTimeline ? 15 : 14,
                            ),
                          ),
                        ),
                        if (post.businessName != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              post.businessName!,
                              style: TextStyle(
                                color: FirstVueColors.teal.withValues(alpha: .85),
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ProfileActivityService.formatRelativeTime(post.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onDelete != null)
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.more_horiz, color: Colors.white54),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
        if (post.body.isNotEmpty) ...[
          SizedBox(height: _isTimeline ? 10 : 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isTimeline ? 0 : 14),
            child: Text(
              post.body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .92),
                height: 1.45,
                fontSize: _isTimeline ? 15 : 14,
              ),
            ),
          ),
        ],
        if (post.media.isNotEmpty) ...[
          SizedBox(height: _isTimeline ? 12 : 10),
          _NewsPostMediaBlock(
            media: post.media,
            timeline: _isTimeline,
            compact: _style == CommunityNewsPostCardStyle.compact,
            sparkFlash: _sparkFlash,
            onDoubleTapSpark:
                widget.onSpark != null ? _handleDoubleTapSpark : null,
          ),
        ],
        if (post.sparkCount > 0 &&
            (widget.onSpark != null ||
                widget.onComment != null ||
                widget.onSave != null)) ...[
          SizedBox(height: _isTimeline ? 8 : 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isTimeline ? 0 : 14),
            child: Text(
              '${post.sparkCount} spark${post.sparkCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (widget.onSpark != null ||
            widget.onComment != null ||
            widget.onSave != null) ...[
          SizedBox(height: _isTimeline ? 4 : 2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isTimeline ? 0 : 4),
            child: Row(
              children: [
                if (widget.onSpark != null)
                  Expanded(
                    child: _ActionButton(
                      icon: post.sparkedByMe
                          ? Icons.bolt_rounded
                          : Icons.bolt_outlined,
                      label: post.sparkCount > 0
                          ? '${post.sparkCount}'
                          : 'Spark',
                      active: post.sparkedByMe,
                      activeColor: FirstVueColors.gold,
                      onTap: widget.onSpark!,
                    ),
                  ),
                if (widget.onComment != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Comment',
                      onTap: widget.onComment!,
                    ),
                  ),
                if (widget.onSave != null)
                  Expanded(
                    child: _ActionButton(
                      icon: post.savedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: post.savedByMe ? 'Saved' : 'Save',
                      active: post.savedByMe,
                      activeColor: FirstVueColors.gold,
                      onTap: widget.onSave!,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_isTimeline) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withValues(alpha: .08)),
        ],
      ],
    );

    if (_isTimeline) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: content,
          ),
        ),
      );
    }

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: content,
    );

    if (widget.onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? (activeColor ?? FirstVueColors.gold)
        : Colors.white.withValues(alpha: .65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsPostMediaBlock extends StatelessWidget {
  final List<CommunityNewsMediaItem> media;
  final bool timeline;
  final bool compact;
  final Animation<double> sparkFlash;
  final VoidCallback? onDoubleTapSpark;

  const _NewsPostMediaBlock({
    required this.media,
    required this.timeline,
    required this.compact,
    required this.sparkFlash,
    this.onDoubleTapSpark,
  });

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      return _MediaTile(
        item: media.first,
        height: timeline ? 280 : (compact ? 180 : 220),
        fullWidth: timeline,
        sparkFlash: sparkFlash,
        onDoubleTapSpark: onDoubleTapSpark,
      );
    }

    final height = timeline ? 260.0 : (compact ? 140.0 : 200.0);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: timeline ? 0 : 14),
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _MediaTile(
            item: media[index],
            height: height,
            width: height * 0.85,
            sparkFlash: sparkFlash,
            onDoubleTapSpark: onDoubleTapSpark,
          );
        },
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final CommunityNewsMediaItem item;
  final double height;
  final double? width;
  final bool fullWidth;
  final Animation<double> sparkFlash;
  final VoidCallback? onDoubleTapSpark;

  const _MediaTile({
    required this.item,
    required this.height,
    this.width,
    this.fullWidth = false,
    required this.sparkFlash,
    this.onDoubleTapSpark,
  });

  @override
  Widget build(BuildContext context) {
    final tileWidth = fullWidth ? double.infinity : (width ?? height);

    return GestureDetector(
      onTap: item.isVideo
          ? null
          : () => openSignedMedia(
                context,
                url: item.signedUrl,
                isVideo: false,
                title: 'PHOTO',
              ),
      onDoubleTap: onDoubleTapSpark,
      child: AnimatedBuilder(
        animation: sparkFlash,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(fullWidth ? 0 : 12),
                child: child,
              ),
              if (sparkFlash.value > 0)
                IgnorePointer(
                  child: Opacity(
                    opacity: (1 - sparkFlash.value).clamp(0.0, 1.0),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 72,
                      color: FirstVueColors.gold.withValues(alpha: .85),
                    ),
                  ),
                ),
            ],
          );
        },
        child: item.isVideo
            ? FeedAutoplayVideo(
                url: item.signedUrl,
                width: tileWidth,
                height: height,
                borderRadius: BorderRadius.circular(fullWidth ? 0 : 12),
                onTap: () => openSignedMedia(
                  context,
                  url: item.signedUrl,
                  isVideo: true,
                  title: 'VIDEO',
                ),
              )
            : SignedMediaThumbnail(
                url: item.signedUrl,
                isVideo: false,
                width: tileWidth,
                height: height,
                borderRadius: BorderRadius.circular(fullWidth ? 0 : 12),
              ),
      ),
    );
  }
}

/// Confirms and deletes a post; returns true if deleted.
Future<bool> confirmDeleteNewsPost(
  BuildContext context,
  CommunityNewsPost post,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF10151B),
      title: const Text('Delete post?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'This removes your post and any attached photos or videos. This cannot be undone.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: FirstVueColors.coral),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    await CommunityNewsService.deletePost(post.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this post.')),
      );
    }
    return false;
  }
}
