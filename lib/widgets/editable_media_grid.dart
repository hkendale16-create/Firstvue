import 'package:flutter/material.dart';

import '../theme/firstvue_theme.dart';
import 'signed_media_viewer.dart';

class EditableMediaGridItem {
  final String id;
  final String signedUrl;
  final bool isVideo;
  final bool featuredForTrending;

  const EditableMediaGridItem({
    required this.id,
    required this.signedUrl,
    required this.isVideo,
    required this.featuredForTrending,
  });
}

class EditableMediaGrid extends StatelessWidget {
  final List<EditableMediaGridItem> items;
  final ValueChanged<EditableMediaGridItem> onDelete;
  final ValueChanged<EditableMediaGridItem> onSetTrendingFeatured;
  final String trendingHint;

  const EditableMediaGrid({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onSetTrendingFeatured,
    this.trendingHint = 'Tap the star to choose what shows in Trending Near You.',
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trendingHint,
          style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap a photo or video to preview.',
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final media = items[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => openSignedMedia(
                      context,
                      url: media.signedUrl,
                      isVideo: media.isVideo,
                      title: media.isVideo ? 'VIDEO' : 'PHOTO',
                    ),
                    child: SignedMediaThumbnail(
                      url: media.signedUrl,
                      isVideo: media.isVideo,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: media.featuredForTrending
                          ? 'Trending cover'
                          : 'Use for Trending',
                      style: IconButton.styleFrom(
                        backgroundColor: media.featuredForTrending
                            ? FirstVueColors.gold.withValues(alpha: .9)
                            : const Color(0xFF10151B).withValues(alpha: .85),
                        foregroundColor: media.featuredForTrending
                            ? Colors.black
                            : Colors.white70,
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onSetTrendingFeatured(media),
                      icon: Icon(
                        media.featuredForTrending ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 16,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete',
                      onPressed: () => onDelete(media),
                      icon: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
