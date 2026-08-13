import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    color: i == selectedIndex
                        ? const Color(0xFF17130B)
                        : fv.secondaryText,
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

  const SocialFollowButton({
    super.key,
    this.label = 'Follow',
    this.onPressed,
    this.filled = true,
    this.compact = false,
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
          backgroundColor: FirstVueColors.gold,
          foregroundColor: const Color(0xFF17130B),
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

/// Horizontal “People to follow” cards driven by nearby trending businesses.
class PeopleToFollowRow extends StatefulWidget {
  const PeopleToFollowRow({super.key});

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
        SocialSectionHeader(title: 'People to follow'),
        const SizedBox(height: 12),
        SizedBox(
          height: 168,
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
                  final role = item.services.isNotEmpty
                      ? item.services.first
                      : 'Local pro';
                  return Container(
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
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: FirstVueColors.gold,
                                )
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
                          style: TextStyle(
                            color: fv.tertiaryText,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        SocialFollowButton(
                          compact: true,
                          onPressed: () {
                            Navigator.push(
                              context,
                              FirstVuePageRoute(
                                builder: (_) => FirstVueBusinessProfileScreen(
                                  businessId: item.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class SocialMasonryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? assetImage;
  final String? likeLabel;
  final VoidCallback onTap;
  final bool showPlay;

  const SocialMasonryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.imageUrl,
    this.assetImage,
    this.likeLabel,
    this.showPlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
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
                  _tileImage(),
                  if (likeLabel != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                    ),
                  if (showPlay)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fv.tertiaryText, fontSize: 11),
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
        errorBuilder: (_, _, _) => _fallback(),
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

class SocialFeedCard extends StatelessWidget {
  final String name;
  final String handle;
  final String body;
  final String? imageUrl;
  final String? assetImage;
  final String? meta;
  final VoidCallback? onTap;
  final VoidCallback? onFollow;

  const SocialFeedCard({
    super.key,
    required this.name,
    required this.handle,
    required this.body,
    this.imageUrl,
    this.assetImage,
    this.meta,
    this.onTap,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fv.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: fv.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
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
                  const SizedBox(width: 10),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          meta == null ? handle : '$handle · $meta',
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
                  SocialFollowButton(compact: true, onPressed: onFollow ?? onTap),
                ],
              ),
              const SizedBox(height: 10),
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
                              assetImage ?? 'assets/images/explore_salons.jpg',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(assetImage!, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.favorite_border, size: 18, color: fv.mutedIcon),
                  const SizedBox(width: 14),
                  Icon(Icons.mode_comment_outlined, size: 18, color: fv.mutedIcon),
                  const SizedBox(width: 14),
                  Icon(Icons.ios_share_outlined, size: 18, color: fv.mutedIcon),
                  const Spacer(),
                  const Icon(
                    Icons.bookmark_border_rounded,
                    size: 18,
                    color: FirstVueColors.gold,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
