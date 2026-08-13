import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/community_detail_screen.dart';
import '../screens/full_screen_media_viewer.dart';
import '../services/community_news_media_service.dart';
import '../services/community_news_service.dart';
import '../services/firstvue_feedback_sounds.dart';
import '../services/profile_activity_service.dart';
import '../theme/firstvue_theme.dart';
import 'group_circle_avatar.dart';
import 'spark_users_sheet.dart';
import 'profile_avatar_thumbnail.dart';
import 'social_rich_text.dart';
import 'feed_autoplay_video.dart';
import 'spark_reaction_button.dart';
import 'signed_media_viewer.dart';
import 'entity_follow_button.dart';

enum CommunityNewsPostCardStyle { compact, timeline }

class CommunityNewsPostCard extends StatefulWidget {
  final CommunityNewsPost post;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onSpark;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onRepost;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool repostedByMe;
  final bool compact;
  final CommunityNewsPostCardStyle style;

  const CommunityNewsPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.onSpark,
    this.onSave,
    this.onComment,
    this.onRepost,
    this.onShare,
    this.onDelete,
    this.repostedByMe = false,
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
    FirstVueFeedbackSounds.playSpark(fromUserTap: true);
    _sparkFlashController.forward(from: 0);
  }

  String _authorInitial() {
    final trimmed = post.authorName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  Widget _buildAuthorHeader() {
    final horizontalPadding = _isTimeline ? 0.0 : 14.0;
    final topPadding = _isTimeline ? 0.0 : 14.0;

    final row = Row(
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
                        color: context.fv.primaryText,
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
              if (post.communityName != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: post.communityId == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            FirstVuePageRoute(
                              builder: (_) => CommunityDetailScreen(
                                communityId: post.communityId!,
                              ),
                            ),
                          );
                        },
                  child: Row(
                    children: [
                      GroupCircleAvatar(
                        imageUrl: post.communityImageUrl,
                        size: 18,
                        fallbackIcon: Icons.groups_rounded,
                        ringColor: FirstVueColors.gold.withValues(alpha: .55),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          post.communityName!,
                          style: TextStyle(
                            color: FirstVueColors.gold.withValues(alpha: .85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (post.authorUsername != null) ...[
                const SizedBox(height: 2),
                Text(
                  '@${post.authorUsername}',
                  style: TextStyle(
                    color: FirstVueColors.teal.withValues(alpha: .75),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                ProfileActivityService.formatRelativeTime(post.createdAt),
                style: TextStyle(
                  color: context.fv.tertiaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (widget.onDelete != null)
          IconButton(
            onPressed: widget.onDelete,
            icon: Icon(Icons.more_horiz, color: context.fv.secondaryText),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        0,
      ),
      child: row,
    );

    if (widget.onAuthorTap == null) return header;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onAuthorTap,
        child: header,
      ),
    );
  }

  Widget _buildPostContent() {
    final bgFill = CommunityNewsPost.backgroundFill(post.backgroundColor);
    final bodyText = post.body.isNotEmpty
        ? Padding(
            padding: EdgeInsets.symmetric(horizontal: _isTimeline ? 0 : 14),
            child: SocialRichText(
              text: post.body,
              style: TextStyle(
                color: context.fv.primaryText,
                height: 1.45,
                fontSize: _isTimeline ? 15 : 14,
              ),
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bodyText != null) ...[
          SizedBox(height: _isTimeline ? 10 : 8),
          if (bgFill != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _isTimeline ? 0 : 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SocialRichText(
                  text: post.body,
                  style: TextStyle(
                    color: context.fv.primaryText,
                    height: 1.45,
                    fontSize: _isTimeline ? 15 : 14,
                  ),
                ),
              ),
            )
          else
            bodyText,
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
                color: context.fv.tertiaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPostActions() {
    if (widget.onSpark == null &&
        widget.onComment == null &&
        widget.onSave == null &&
        widget.onRepost == null &&
        widget.onShare == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isTimeline ? 0 : 4,
        _isTimeline ? 4 : 2,
        _isTimeline ? 0 : 4,
        0,
      ),
      child: Row(
        children: [
          if (widget.onSpark != null)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: StopPropagation(
                  child: SparkReactionButton(
                    sparked: post.sparkedByMe,
                    count: post.sparkCount,
                    onPressed: () {
                      FirstVueFeedbackSounds.playSpark(fromUserTap: true);
                      widget.onSpark!();
                    },
                  ),
                ),
              ),
            ),
          if (widget.onComment != null)
            Expanded(
              child: StopPropagation(
                child: _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Comment',
                  onTap: widget.onComment!,
                ),
              ),
            ),
          if (widget.onRepost != null)
            Expanded(
              child: StopPropagation(
                child: _ActionButton(
                  icon: widget.repostedByMe
                      ? Icons.repeat_rounded
                      : Icons.repeat_outlined,
                  label: widget.repostedByMe
                      ? 'Reposted'
                      : (post.repostCount > 0
                          ? 'Repost · ${post.repostCount}'
                          : 'Repost'),
                  active: widget.repostedByMe,
                  activeColor: FirstVueColors.teal,
                  onTap: widget.onRepost!,
                ),
              ),
            ),
          if (widget.onShare != null)
            Expanded(
              child: StopPropagation(
                child: _ActionButton(
                  icon: Icons.ios_share_outlined,
                  label: 'Share',
                  onTap: widget.onShare!,
                ),
              ),
            ),
          if (widget.onSave != null)
            Expanded(
              child: StopPropagation(
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
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isTimeline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorHeader(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _buildPostContent(),
              ),
            ),
          ),
          _buildPostActions(),
          _buildSparkPreview(),
          const SizedBox(height: 14),
          Divider(height: 1, color: context.fv.borderSubtle),
        ],
      );
    }

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorHeader(),
          if (widget.onTap == null)
            _buildPostContent()
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: _buildPostContent(),
              ),
            ),
          _buildPostActions(),
          _buildSparkPreview(),
          const SizedBox(height: 8),
          Divider(height: 1, color: Color(0x14FFFFFF)),
        ],
      ),
    );

    return card;
  }

  Widget _buildSparkPreview() {
    if (post.sparkCount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(_isTimeline ? 0 : 14, 0, _isTimeline ? 0 : 14, 4),
      child: _SparkAvatarStrip(postId: post.id, total: post.sparkCount),
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
        : context.fv.secondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(icon, size: 20, color: color),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkAvatarStrip extends StatefulWidget {
  final String postId;
  final int total;

  const _SparkAvatarStrip({required this.postId, required this.total});

  @override
  State<_SparkAvatarStrip> createState() => _SparkAvatarStripState();
}

class _SparkAvatarStripState extends State<_SparkAvatarStrip> {
  List<SparkUser> _users = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await CommunityNewsService.fetchSparkUsers(
      widget.postId,
      limit: 6,
    );
    if (!mounted) return;
    setState(() {
      _users = users;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _users.isEmpty) return const SizedBox.shrink();

    final extra = widget.total > _users.length ? widget.total - _users.length : 0;

    return GestureDetector(
      onTap: () => SparkUsersSheet.show(context, postId: widget.postId),
      child: Row(
        children: [
          SizedBox(
            height: 26,
            width: 26 + (_users.length - 1) * 16.0 + (extra > 0 ? 16 : 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < _users.length; i++)
                  Positioned(
                    left: i * 16.0,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      child: ProfileAvatarThumbnail(
                        imageUrl: _users[i].avatarUrl,
                        displayName: _users[i].displayName,
                        radius: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (extra > 0) ...[
            const SizedBox(width: 6),
            Text(
              '+$extra',
              style: TextStyle(
                color: context.fv.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
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
      onTap: () {
        if (item.isVideo) {
          openFullScreenVideoPlayer(
            context,
            url: item.signedUrl,
            title: 'VIDEO',
            loop: true,
          );
        } else {
          openFullScreenImageViewer(
            context,
            items: [
              FullScreenMediaItem(url: item.signedUrl, isVideo: false),
            ],
            title: 'PHOTO',
          );
        }
      },
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
                onTap: () => openFullScreenVideoPlayer(
                  context,
                  url: item.signedUrl,
                  title: 'VIDEO',
                  loop: true,
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
      backgroundColor: ctx.fv.surface,
      title: Text('Delete post?', style: TextStyle(color: ctx.fv.primaryText)),
      content: Text(
        'This removes your post and any attached photos or videos. This cannot be undone.',
        style: TextStyle(color: ctx.fv.secondaryText),
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
