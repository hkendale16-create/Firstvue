import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/community_news_media_service.dart';
import '../services/community_news_service.dart';
import '../services/profile_activity_service.dart';
import '../theme/firstvue_theme.dart';

class CommunityNewsPostCard extends StatelessWidget {
  final CommunityNewsPost post;
  final VoidCallback? onTap;
  final VoidCallback? onSpark;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final bool compact;

  const CommunityNewsPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onSpark,
    this.onSave,
    this.onComment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.authorName,
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
              if (post.businessName != null)
                Text(
                  post.businessName!,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ProfileActivityService.formatRelativeTime(post.createdAt),
            style: TextStyle(
              color: Colors.white.withValues(alpha: .35),
              fontSize: 10,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          if (post.body.isNotEmpty)
            Text(
              post.body,
              style: TextStyle(
                color: Colors.white,
                height: 1.4,
                fontSize: compact ? 13 : 14,
              ),
            ),
          if (post.media.isNotEmpty) ...[
            SizedBox(height: compact ? 8 : 10),
            _NewsPostMediaStrip(media: post.media, compact: compact),
          ],
          if (onSpark != null || onComment != null || onSave != null) ...[
            SizedBox(height: compact ? 6 : 10),
            Row(
              children: [
                if (onSpark != null)
                  TextButton.icon(
                    onPressed: onSpark,
                    style: TextButton.styleFrom(
                      foregroundColor: post.sparkedByMe
                          ? FirstVueColors.gold
                          : Colors.white70,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      post.sparkedByMe
                          ? Icons.bolt_rounded
                          : Icons.bolt_outlined,
                      size: 16,
                      color: post.sparkedByMe
                          ? FirstVueColors.gold
                          : Colors.white70,
                    ),
                    label: Text('${post.sparkCount} sparks'),
                  ),
                if (onComment != null)
                  TextButton.icon(
                    onPressed: onComment,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Comment'),
                  ),
                if (onSave != null)
                  TextButton.icon(
                    onPressed: onSave,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          post.savedByMe ? FirstVueColors.gold : Colors.white70,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: Icon(
                      post.savedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border,
                      size: 16,
                      color:
                          post.savedByMe ? FirstVueColors.gold : Colors.white70,
                    ),
                    label: Text(post.savedByMe ? 'Saved' : 'Save'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _NewsPostMediaStrip extends StatelessWidget {
  final List<CommunityNewsMediaItem> media;
  final bool compact;

  const _NewsPostMediaStrip({
    required this.media,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact ? 120.0 : 160.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = media[index];
          return GestureDetector(
            onTap: () => _openMedia(context, item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.isVideo
                  ? Container(
                      width: height * 1.2,
                      height: height,
                      color: FirstVueColors.elevatedSurface,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, color: FirstVueColors.teal, size: 40),
                          SizedBox(height: 6),
                          Text('Video', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    )
                  : Image.network(
                      item.signedUrl,
                      width: height * 1.2,
                      height: height,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: height * 1.2,
                        height: height,
                        color: FirstVueColors.elevatedSurface,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openMedia(BuildContext context, CommunityNewsMediaItem item) async {
    if (item.isVideo) {
      final uri = Uri.parse(item.signedUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(item.signedUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
