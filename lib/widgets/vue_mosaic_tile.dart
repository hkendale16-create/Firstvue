import 'package:flutter/material.dart';

import '../services/discovery_feed_service.dart';
import '../theme/firstvue_theme.dart';
import 'network_photo.dart';
import 'social_chrome.dart';

/// Cover-cropped VUE mosaic tile. Photos never show a video glyph.
class VueMosaicTile extends StatelessWidget {
  final DiscoveryFeedItem item;
  final bool featured;
  final VoidCallback onOpen;
  final VoidCallback onOpenProfile;

  const VueMosaicTile({
    super.key,
    required this.item,
    required this.featured,
    required this.onOpen,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final handle = item.handle?.trim().isNotEmpty == true
        ? item.handle!
        : (item.isMember
              ? socialHandleFromName(item.ownerName)
              : socialHandleFromName(item.businessName));
    final categoryLine = [
      item.businessType,
      if (item.services.isNotEmpty) item.services.first,
    ].where((part) => part.trim().isNotEmpty).take(2).join(' · ');
    final location = item.locationLabel?.trim() ?? '';
    // Never decode a video object URL with Image.network — that freezes /
    // stalls Flutter web (and Safari) while scrolling the mosaic.
    final poster = item.thumbnailUrl?.trim() ?? '';
    final safeImageUrl = (!item.isVideo && poster.isEmpty)
        ? item.mediaUrl.trim()
        : poster;
    final showVideoChrome = item.isVideo;
    final nameSize = featured ? 13.0 : 11.0;
    final metaSize = featured ? 11.0 : 10.0;
    final avatarRadius = featured ? 13.0 : 11.0;

    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(featured ? 6 : 3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _media(fv, safeImageUrl),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            if (item.liveNow)
              const Positioned(top: 8, left: 8, child: _LiveNowBadge()),
            if (showVideoChrome)
              Positioned(
                top: 8,
                right: 8,
                child: _VideoIndicator(durationLabel: item.durationLabel),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  featured ? 10 : 8,
                  18,
                  featured ? 10 : 8,
                  featured ? 10 : 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onOpenProfile,
                      child: NetworkCircleAvatar(
                        imageUrl:
                            item.avatarUrl != null &&
                                item.avatarUrl!.startsWith('http')
                            ? item.avatarUrl
                            : null,
                        radius: avatarRadius,
                        backgroundColor: fv.elevatedSurface,
                        placeholder: Icon(
                          item.isMember
                              ? Icons.person_rounded
                              : Icons.storefront_rounded,
                          size: featured ? 14 : 12,
                          color: FirstVueColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    handle.startsWith('@')
                                        ? handle
                                        : '@$handle',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: nameSize,
                                      height: 1.1,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (item.verified) ...[
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.verified,
                                    color: FirstVueColors.gold,
                                    size: featured ? 14 : 12,
                                  ),
                                ],
                              ],
                            ),
                            if (location.isNotEmpty)
                              Text(
                                location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .86),
                                  fontSize: metaSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (categoryLine.isNotEmpty)
                              Text(
                                categoryLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .74),
                                  fontSize: metaSize,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _media(FirstVuePalette fv, String thumbUrl) {
    // Mosaic tiles stay still: cover-crop a real image poster. Playback
    // happens in the full-screen viewer so the grid never sizes from video.
    if (thumbUrl.startsWith('http') && !_looksLikeVideoUrl(thumbUrl)) {
      return SizedBox.expand(
        child: NetworkPhoto(url: thumbUrl, fit: BoxFit.cover),
      );
    }
    return ColoredBox(
      color: fv.elevatedSurface,
      child: item.isVideo
          ? const Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white54,
                size: 36,
              ),
            )
          : Icon(Icons.photo_outlined, color: fv.mutedIcon),
    );
  }

  static bool _looksLikeVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.mov') ||
        lower.contains('.mp4') ||
        lower.contains('.webm') ||
        lower.contains('.m4v') ||
        lower.contains('video/');
  }
}

class _VideoIndicator extends StatelessWidget {
  final String? durationLabel;

  const _VideoIndicator({this.durationLabel});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 13,
              key: Key('vue-video-indicator'),
            ),
            if (durationLabel != null && durationLabel!.trim().isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                durationLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveNowBadge extends StatelessWidget {
  const _LiveNowBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FirstVueColors.teal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}
