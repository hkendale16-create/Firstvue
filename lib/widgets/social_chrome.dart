import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../services/event_social_service.dart';
import '../services/things_to_do_service.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import 'event_profile_sheet.dart';
import 'entity_follow_button.dart';
import 'explore_grid_video.dart';
import 'facebook_style_profile_header.dart';
import 'firstvue_inline_search_bar.dart';

const _goldOnWhite = Colors.white;
const _searchHint = 'Search for people, places, or services.';

String socialHandleFromName(String name) {
  final cleaned = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  if (cleaned.isEmpty) return '@firstvue';
  return '@$cleaned';
}

/// Gold filled pill vs outline pill, matching the locked mockups.
class SocialPillTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SocialPillTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? FirstVueColors.gold
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: i == selectedIndex
                        ? FirstVueColors.gold
                        : fv.borderSubtle,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: i == selectedIndex ? _goldOnWhite : fv.secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SocialFollowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool compact;
  final Color? fillColor;

  const SocialFollowButton({
    super.key,
    this.label = 'Follow',
    this.onPressed,
    this.filled = true,
    this.compact = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fillColor ?? FirstVueColors.gold,
          foregroundColor: _goldOnWhite,
          padding: padding,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FirstVueColors.gold,
        side: const BorderSide(color: FirstVueColors.gold),
        padding: padding,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class SocialSearchBar extends StatelessWidget {
  final String hintText;
  final bool autofocus;
  final VoidCallback? onFilterTap;
  final bool filterActive;

  const SocialSearchBar({
    super.key,
    this.hintText = _searchHint,
    this.autofocus = false,
    this.onFilterTap,
    this.filterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return FirstVueInlineSearchBar(
      hintText: hintText,
      autofocus: autofocus,
      padding: EdgeInsets.zero,
      showOpenButton: false,
      onFilterTap: onFilterTap,
      filterActive: filterActive,
    );
  }
}

class SocialPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool centered;

  const SocialPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final align = centered ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: const TextStyle(
            fontFamily: 'CormorantGaramond',
            color: FirstVueColors.gold,
            fontSize: 28,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: align,
            style: TextStyle(
              color: context.fv.secondaryText,
              height: 1.4,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class SocialSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SocialSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.fv.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: FirstVueColors.gold,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class SocialGoldUnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const SocialGoldUnderlineTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: selectedIndex == i
                              ? FirstVueColors.gold
                              : context.fv.secondaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 2,
                        width: selectedIndex == i ? 28 : 0,
                        decoration: BoxDecoration(
                          color: FirstVueColors.gold,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal “Consider Following” cards driven by nearby trending businesses.
class PeopleToFollowRow extends StatefulWidget {
  const PeopleToFollowRow({
    super.key,
    this.onSeeAll,
    this.title = 'Consider Following',
  });

  final VoidCallback? onSeeAll;
  final String title;

  @override
  State<PeopleToFollowRow> createState() => _PeopleToFollowRowState();
}

class _PeopleToFollowRowState extends State<PeopleToFollowRow> {
  late Future<List<TrendingBusiness>> _future;

  @override
  void initState() {
    super.initState();
    _future = TrendingBusinessesService.fetchTrendingNearYou(limit: 8);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SocialSectionHeader(
          title: widget.title,
          actionLabel: widget.onSeeAll != null ? 'See all' : null,
          onAction: widget.onSeeAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 176,
          child: FutureBuilder<List<TrendingBusiness>>(
            future: _future,
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <TrendingBusiness>[];
              if (snapshot.connectionState == ConnectionState.waiting &&
                  items.isEmpty) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (items.isEmpty) {
                return Text(
                  'Local pros to follow will show up here.',
                  style: TextStyle(color: fv.secondaryText, fontSize: 13),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _PeopleFollowCard(item: item);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeopleFollowCard extends StatelessWidget {
  final TrendingBusiness item;

  const _PeopleFollowCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final role = peopleFollowRoleLabel(item.services);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => FirstVueBusinessProfileScreen(businessId: item.id),
          ),
        );
      },
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: fv.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fv.borderSubtle),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: fv.elevatedSurface,
              backgroundImage: item.imageUrl != null
                  ? NetworkImage(item.imageUrl!)
                  : null,
              child: item.imageUrl == null
                  ? const Icon(Icons.person_rounded, color: FirstVueColors.gold)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fv.tertiaryText, fontSize: 11),
            ),
            const Spacer(),
            EntityFollowButton(
              kind: FollowTargetKind.business,
              targetId: item.id,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

String peopleFollowRoleLabel(List<String> services) {
  final joined = services.join(' ').toLowerCase();
  if (joined.contains('barber') || joined.contains('cut')) {
    return 'Barber ✂️';
  }
  if (joined.contains('salon') ||
      joined.contains('hair') ||
      joined.contains('beauty') ||
      joined.contains('stylist')) {
    return 'Salon Owner ✨';
  }
  if (joined.contains('chef') ||
      joined.contains('restaurant') ||
      joined.contains('food') ||
      joined.contains('dining')) {
    return 'Chef 🍽️';
  }
  if (services.isNotEmpty) return services.first;
  return 'Local pro';
}

/// Masonry / grid photo tile: image overlays + avatar / @handle footer.
class SocialPostTile extends StatelessWidget {
  final String handle;
  final VoidCallback onTap;
  final String? avatarUrl;
  final String? imageUrl;
  final String? assetImage;
  final String? videoUrl;
  final String? likeLabel;
  final String? dateLabel;
  final String? durationLabel;
  final bool live;
  final bool showPlay;
  final bool showBookmark;
  final bool showFollowOverlay;
  final bool showOutlineFollow;
  final bool showMenu;
  final VoidCallback? onFollow;
  final VoidCallback? onMenu;

  const SocialPostTile({
    super.key,
    required this.handle,
    required this.onTap,
    this.avatarUrl,
    this.imageUrl,
    this.assetImage,
    this.videoUrl,
    this.likeLabel,
    this.dateLabel,
    this.durationLabel,
    this.live = false,
    this.showPlay = false,
    this.showBookmark = false,
    this.showFollowOverlay = false,
    this.showOutlineFollow = false,
    this.showMenu = true,
    this.onFollow,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final hasVideo = videoUrl != null && videoUrl!.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasVideo)
                    ExploreGridVideo(
                      url: videoUrl!,
                      thumbnailUrl: imageUrl,
                      onTap: onTap,
                    )
                  else
                    _tileImage(),
                  if (live)
                    const Positioned(top: 8, left: 8, child: _LiveBadge()),
                  if (dateLabel != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dateLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                    ),
                  if (likeLabel != null)
                    Positioned(
                      top: showBookmark ? null : 8,
                      bottom: showBookmark ? 8 : null,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likeLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (showFollowOverlay && onFollow != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: StopPropagation(
                        child: GestureDetector(
                          onTap: onFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'Follow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showBookmark)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.bookmark_rounded,
                        color: FirstVueColors.gold,
                        size: 20,
                      ),
                    ),
                  if (durationLabel != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Text(
                        durationLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: fv.elevatedSurface,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 12,
                        color: FirstVueColors.gold,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  handle.startsWith('@') ? handle : '@$handle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (showOutlineFollow && onFollow != null)
                StopPropagation(
                  child: SocialFollowButton(
                    compact: true,
                    filled: false,
                    onPressed: onFollow,
                  ),
                )
              else if (showMenu)
                GestureDetector(
                  onTap: onMenu ?? onTap,
                  child: Icon(Icons.more_horiz, size: 18, color: fv.mutedIcon),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tileImage() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => assetImage != null
            ? Image.asset(assetImage!, fit: BoxFit.cover)
            : _fallback(),
      );
    }
    if (assetImage != null) {
      return Image.asset(
        assetImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return const ColoredBox(
      color: Color(0xFFEEEAE4),
      child: Icon(Icons.photo_outlined, color: FirstVueColors.gold),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FirstVueColors.teal,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class SocialPhotoGrid extends StatelessWidget {
  final List<SocialPhotoGridItem> items;
  final int crossAxisCount;

  const SocialPhotoGrid({
    super.key,
    required this.items,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No posts yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.fv.secondaryText),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: item.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                  Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFEEEAE4)),
                  )
                else if (item.assetImage != null)
                  Image.asset(item.assetImage!, fit: BoxFit.cover)
                else
                  ColoredBox(
                    color: context.fv.elevatedSurface,
                    child: const Icon(
                      Icons.photo_outlined,
                      color: FirstVueColors.gold,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SocialPhotoGridItem {
  final String? imageUrl;
  final String? assetImage;
  final bool isVideo;
  final VoidCallback onTap;

  const SocialPhotoGridItem({
    required this.onTap,
    this.imageUrl,
    this.assetImage,
    this.isVideo = false,
  });
}

class SocialFeedCard extends StatelessWidget {
  final String name;
  final String handle;
  final String body;
  final String? imageUrl;
  final String? assetImage;
  final String? meta;
  final bool verified;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final bool liked;
  final bool saved;
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final String? followBusinessId;

  const SocialFeedCard({
    super.key,
    required this.name,
    required this.handle,
    required this.body,
    this.imageUrl,
    this.assetImage,
    this.meta,
    this.verified = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.liked = false,
    this.saved = false,
    this.onTap,
    this.onProfileTap,
    this.onFollow,
    this.onMore,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.followBusinessId,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final handleLine = meta == null ? handle : '$handle · $meta';
    final openProfile = onProfileTap ?? onTap;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: openProfile,
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: fv.elevatedSurface,
                    backgroundImage: imageUrl != null
                        ? NetworkImage(imageUrl!)
                        : null,
                    child: imageUrl == null
                        ? const Icon(
                            Icons.storefront_outlined,
                            color: FirstVueColors.gold,
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: openProfile,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: fv.primaryText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  color: Color(0xFF1D9BF0),
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            handleLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              StopPropagation(
                child:
                    followBusinessId != null &&
                        followBusinessId!.trim().isNotEmpty
                    ? EntityFollowButton(
                        kind: FollowTargetKind.business,
                        targetId: followBusinessId!,
                        compact: true,
                      )
                    : (onFollow != null
                          ? SocialFollowButton(
                              compact: true,
                              onPressed: onFollow,
                            )
                          : const SizedBox.shrink()),
              ),
              StopPropagation(
                child: IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_horiz, color: fv.mutedIcon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    body,
                    style: TextStyle(color: fv.primaryText, height: 1.35),
                  ),
                  if (imageUrl != null || assetImage != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Image.asset(
                                  assetImage ??
                                      'assets/images/explore_salons.jpg',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(assetImage!, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _FeedActionHitTarget(
                onTap: onLike,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: liked ? FirstVueColors.coral : fv.mutedIcon,
                    ),
                    if (likeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$likeCount',
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FeedActionHitTarget(
                onTap: onComment,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mode_comment_outlined,
                      size: 20,
                      color: fv.mutedIcon,
                    ),
                    if (commentCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$commentCount',
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FeedActionHitTarget(
                onTap: onShare,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.ios_share_outlined,
                      size: 20,
                      color: fv.mutedIcon,
                    ),
                    if (shareCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$shareCount',
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              _FeedActionHitTarget(
                onTap: onSave,
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: saved ? FirstVueColors.gold : FirstVueColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedActionHitTarget extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _FeedActionHitTarget({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StopPropagation(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SocialEventCard extends StatefulWidget {
  final CommunityEvent event;

  const SocialEventCard({super.key, required this.event});

  @override
  State<SocialEventCard> createState() => _SocialEventCardState();
}

class _SocialEventCardState extends State<SocialEventCard> {
  bool _going = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await EventSocialService.fetchState(widget.event.id);
    if (!mounted) return;
    setState(() {
      _going = state.attendance == EventAttendanceStatus.attending;
    });
  }

  Future<void> _toggleGoing() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_going) {
        await EventSocialService.clearAttendance(widget.event.id);
        if (mounted) setState(() => _going = false);
      } else {
        await EventSocialService.setAttendance(
          widget.event.id,
          EventAttendanceStatus.attending,
        );
        if (mounted) setState(() => _going = true);
      }
    } catch (_) {
      if (!mounted) return;
      EventProfileSheet.show(context, event: widget.event);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final event = widget.event;
    final when = _eventWhen(event);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => EventProfileSheet.show(context, event: event),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: fv.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fv.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: event.coverImageUrl != null
                      ? Image.network(
                          event.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/explore_things_to_do.jpg',
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.asset(
                          'assets/images/explore_things_to_do.jpg',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      when.kicker,
                      style: const TextStyle(
                        color: FirstVueColors.teal,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 13,
                          color: fv.mutedIcon,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.locationLabel ?? 'Local event',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (when.time != null) ...[
                          Icon(
                            Icons.schedule_outlined,
                            size: 13,
                            color: fv.mutedIcon,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            when.time!,
                            style: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (event.description != null &&
                        event.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _going
                                ? 'You and others are going'
                                : 'See who is going',
                            style: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        SocialFollowButton(
                          label: _going ? 'Going' : 'Going',
                          compact: true,
                          fillColor: FirstVueColors.teal,
                          onPressed: _busy ? null : _toggleGoing,
                        ),
                        const SizedBox(width: 6),
                        EntityFollowButton(
                          kind: FollowTargetKind.event,
                          targetId: event.id,
                          compact: true,
                        ),
                      ],
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

  static ({String kicker, String? time}) _eventWhen(CommunityEvent event) {
    final at = event.eventAt;
    if (at == null) {
      return (kicker: 'Tonight in Atlanta', time: null);
    }
    final local = at.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return (
      kicker: '${months[local.month - 1]} ${local.day}',
      time: '$hour:$minute $ampm',
    );
  }
}

class SocialProfileHeader extends StatelessWidget {
  final String name;
  final String? handle;
  final String? bio;
  final String? coverImageUrl;
  final String? avatarImageUrl;
  final bool coverIsVideo;
  final bool avatarIsVideo;
  final bool verified;
  final bool centerAvatar;
  final IconData avatarIcon;
  final List<ProfileStatItem> stats;
  final List<Widget> actions;
  final VoidCallback? onCoverTap;
  final VoidCallback? onAvatarTap;
  final Widget? trailing;

  const SocialProfileHeader({
    super.key,
    required this.name,
    this.handle,
    this.bio,
    this.coverImageUrl,
    this.avatarImageUrl,
    this.coverIsVideo = false,
    this.avatarIsVideo = false,
    this.verified = false,
    this.centerAvatar = false,
    this.avatarIcon = Icons.person_outline,
    this.stats = const [],
    this.actions = const [],
    this.onCoverTap,
    this.onAvatarTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final hasCover = coverImageUrl != null && coverImageUrl!.isNotEmpty;
    final hasAvatar = avatarImageUrl != null && avatarImageUrl!.isNotEmpty;
    final avatar = GestureDetector(
      onTap: onAvatarTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border.all(color: FirstVueColors.gold, width: 3),
        ),
        child: CircleAvatar(
          radius: 44,
          backgroundColor: fv.elevatedSurface,
          backgroundImage: hasAvatar && !avatarIsVideo
              ? NetworkImage(avatarImageUrl!)
              : null,
          child: hasAvatar
              ? null
              : Icon(avatarIcon, color: FirstVueColors.gold, size: 42),
        ),
      ),
    );

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onCoverTap,
              child: SizedBox(
                height: 168,
                width: double.infinity,
                child: hasCover
                    ? Image.network(
                        coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _coverFallback(),
                      )
                    : _coverFallback(),
              ),
            ),
            if (trailing != null)
              Positioned(top: 8, right: 8, child: trailing!),
            Positioned(
              left: centerAvatar ? 0 : 20,
              right: centerAvatar ? 0 : null,
              bottom: -48,
              child: centerAvatar ? Center(child: avatar) : avatar,
            ),
          ],
        ),
        const SizedBox(height: 56),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: centerAvatar
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      textAlign: centerAvatar
                          ? TextAlign.center
                          : TextAlign.start,
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        color: fv.primaryText,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (verified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: FirstVueColors.gold,
                      size: 18,
                    ),
                  ],
                ],
              ),
              if (handle != null && handle!.isNotEmpty)
                Text(
                  handle!.startsWith('@') ? handle! : '@$handle',
                  style: TextStyle(color: fv.tertiaryText, fontSize: 14),
                ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final stat in stats)
                      GestureDetector(
                        onTap: stat.onTap,
                        child: Column(
                          children: [
                            Text(
                              stat.value,
                              style: TextStyle(
                                color: fv.primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              stat.label.toLowerCase(),
                              style: TextStyle(
                                color: fv.tertiaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
              if (bio != null && bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: centerAvatar
                      ? Alignment.center
                      : Alignment.centerLeft,
                  child: Text(
                    bio!,
                    textAlign: centerAvatar
                        ? TextAlign.center
                        : TextAlign.start,
                    style: TextStyle(color: fv.secondaryText, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverFallback() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE5C16F), Color(0xFF3DD9C9)],
        ),
      ),
    );
  }
}
