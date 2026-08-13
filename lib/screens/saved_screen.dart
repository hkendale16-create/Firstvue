import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/saved_items_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/social_chrome.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late Future<List<SavedItem>> _future;
  int _filter = 0;

  static const _filters = ['All', 'Posts', 'Businesses', 'Vues', 'Collections'];

  static const _fallbackAssets = [
    'assets/images/explore_barbers.jpg',
    'assets/images/explore_salons.jpg',
    'assets/images/explore_beauty.jpg',
    'assets/images/explore_restaurants.jpg',
    'assets/images/explore_things_to_do.jpg',
    'assets/images/explore_rentals.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _future = SavedItemsService.fetchRecentSaved();
  }

  Future<void> _refresh() async {
    final next = SavedItemsService.fetchRecentSaved();
    setState(() => _future = next);
    await next;
  }

  Future<void> _open(SavedItem item) async {
    if (item.contentType == SavedContentType.newsPost) {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => PostDetailScreen(postId: item.contentId),
        ),
      );
      return;
    }
    if (item.contentType == SavedContentType.business) {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: item.contentId),
        ),
      );
    }
  }

  Future<void> _unsave(SavedItem item) async {
    await SavedItemsService.unsave(
      contentType: item.contentType,
      contentId: item.contentId,
    );
    await _refresh();
  }

  List<SavedItem> _visible(List<SavedItem> items) {
    return items.where((item) {
      return switch (_filter) {
        1 => item.contentType == SavedContentType.newsPost,
        2 => item.contentType == SavedContentType.business,
        3 => item.contentType == SavedContentType.vueMedia ||
            item.contentType == SavedContentType.story,
        4 => true,
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: FutureBuilder<List<SavedItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: FirstVueColors.gold),
              );
            }
            final items = snapshot.data ?? const <SavedItem>[];
            final visible = _visible(items);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SocialPageHeader(
                          title: 'FAVORITES',
                          subtitle: 'Posts, shops, and Vues you saved.',
                        ),
                        const SizedBox(height: 14),
                        SocialPillTabs(
                          labels: _filters,
                          selectedIndex: _filter,
                          onSelected: (index) =>
                              setState(() => _filter = index),
                        ),
                        const SizedBox(height: 18),
                        _CollectionsRow(items: items),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              color: FirstVueColors.gold,
                              size: 46,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nothing saved yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: fv.primaryText,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'Tap Save on a post, VUE, or business to find it here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: fv.secondaryText,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = visible[index];
                          final asset = _fallbackAssets[
                              index % _fallbackAssets.length];
                          return SocialPostTile(
                            handle: socialHandleFromName(
                              item.authorName ?? item.title,
                            ),
                            assetImage: asset,
                            likeLabel: index.isEven ? '2.1k' : '843',
                            showBookmark: true,
                            dateLabel: item.contentType ==
                                    SavedContentType.story
                                ? 'MAY 24'
                                : null,
                            onTap: () => _open(item),
                            onMenu: () => _unsave(item),
                          );
                        },
                        childCount: visible.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CollectionsRow extends StatelessWidget {
  final List<SavedItem> items;

  const _CollectionsRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final collections = [
      (
        'Midtown cuts',
        items.where((i) => i.contentType == SavedContentType.business).length,
        'assets/images/explore_barbers.jpg',
      ),
      (
        'Date night',
        items.where((i) => i.contentType == SavedContentType.newsPost).length,
        'assets/images/explore_restaurants.jpg',
      ),
      (
        'Hair inspo',
        items.length,
        'assets/images/explore_salons.jpg',
      ),
    ];

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: collections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final collection = collections[index];
          return SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 72,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16,
                        child: _stackCard(collection.$3, 0.7),
                      ),
                      Positioned(
                        left: 8,
                        child: _stackCard(collection.$3, 0.85),
                      ),
                      _stackCard(collection.$3, 1),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  collection.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${collection.$2} saved',
                  style: TextStyle(color: fv.tertiaryText, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stackCard(String asset, double opacity) {
    return Opacity(
      opacity: opacity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          asset,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
