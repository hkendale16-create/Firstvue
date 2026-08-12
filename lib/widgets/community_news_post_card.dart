import 'package:flutter/material.dart';

import '../services/community_news_service.dart';
import '../services/profile_activity_service.dart';
import '../theme/firstvue_theme.dart';

class CommunityNewsPostCard extends StatelessWidget {
  final CommunityNewsPost post;
  final VoidCallback? onSpark;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final bool compact;

  const CommunityNewsPostCard({
    super.key,
    required this.post,
    this.onSpark,
    this.onSave,
    this.onComment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            post.body,
            style: TextStyle(
              color: Colors.white,
              height: 1.4,
              fontSize: compact ? 13 : 14,
            ),
          ),
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
  }
}
