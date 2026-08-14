import 'package:flutter/material.dart';

import '../screens/full_screen_media_viewer.dart';
import '../theme/firstvue_theme.dart';
import 'signed_media_viewer.dart';

class EditableMediaGridItem {
  final String id;
  final String signedUrl;
  final bool isVideo;
  final bool featuredForTrending;
  final String? caption;

  const EditableMediaGridItem({
    required this.id,
    required this.signedUrl,
    required this.isVideo,
    required this.featuredForTrending,
    this.caption,
  });
}

class EditableMediaGrid extends StatelessWidget {
  final List<EditableMediaGridItem> items;
  final ValueChanged<EditableMediaGridItem> onDelete;
  final ValueChanged<EditableMediaGridItem> onSetTrendingFeatured;
  final ValueChanged<EditableMediaGridItem>? onEditCaption;
  final String trendingHint;

  const EditableMediaGrid({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onSetTrendingFeatured,
    this.onEditCaption,
    this.trendingHint = 'Tap the star to choose what shows in Trending Near You.',
  });

  Future<void> _open(BuildContext context, EditableMediaGridItem media) async {
    if (media.isVideo) {
      openSignedMedia(
        context,
        url: media.signedUrl,
        isVideo: true,
        title: 'VIDEO',
      );
      return;
    }
    final images = items
        .where((e) => !e.isVideo)
        .map(
          (e) => FullScreenMediaItem(
            url: e.signedUrl,
            isVideo: false,
            caption: e.caption,
          ),
        )
        .toList();
    final index = images.indexWhere((e) => e.url == media.signedUrl);
    await openFullScreenImageViewer(
      context,
      items: images,
      initialIndex: index < 0 ? 0 : index,
      title: 'PHOTO',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final fv = context.fv;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trendingHint,
          style: TextStyle(color: fv.tertiaryText, fontSize: 11, height: 1.35),
        ),
        const SizedBox(height: 4),
        Text(
          onEditCaption == null
              ? 'Tap a photo or video to preview.'
              : 'Tap a photo to preview. Use the caption icon to edit text.',
          style: TextStyle(color: fv.tertiaryText, fontSize: 10),
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
            final hasCaption = media.caption?.trim().isNotEmpty == true;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => _open(context, media),
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
                            : fv.background.withValues(alpha: .85),
                        foregroundColor: media.featuredForTrending
                            ? Colors.black
                            : fv.primaryText,
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onSetTrendingFeatured(media),
                      icon: Icon(
                        media.featuredForTrending
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
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
                  if (onEditCaption != null)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        visualDensity: VisualDensity.compact,
                        tooltip: hasCaption ? 'Edit caption' : 'Add caption',
                        style: IconButton.styleFrom(
                          backgroundColor: fv.background.withValues(alpha: .85),
                          foregroundColor: FirstVueColors.teal,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => onEditCaption!(media),
                        icon: Icon(
                          hasCaption
                              ? Icons.notes_rounded
                              : Icons.notes_outlined,
                          size: 16,
                        ),
                      ),
                    ),
                  if (hasCaption)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                fv.background.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              6,
                              18,
                              onEditCaption != null ? 34 : 6,
                              6,
                            ),
                            child: Text(
                              media.caption!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fv.primaryText,
                                fontSize: 10,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
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
