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
              return Center(
                child: CircularProgressIndicator(color: FirstVueColors.gold),
              );
            }
            final items = snapshot.data ?? const <SavedItem>[];
            if (items.isEmpty) {
              return FirstVueRefreshScaffold.alwaysScrollable(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bookmark_border,
                          color: Color(0xFFD8B56A),
                          size: 46,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'NOTHING SAVED YET',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: fv.primaryText,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Tap Save on a post, VUE, or business to find it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: fv.secondaryText, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final visible = items.where((item) {
              return switch (_filter) {
                1 => item.contentType == SavedContentType.newsPost,
                2 => item.contentType == SavedContentType.business,
                3 => item.contentType == SavedContentType.vueMedia ||
                    item.contentType == SavedContentType.story,
                _ => true,
              };
            }).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FAVORITES',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            color: FirstVueColors.gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Posts, shops, and Vues you saved.',
                          style: TextStyle(color: fv.secondaryText, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        SocialPillTabs(
                          labels: const [
                            'All',
                            'Posts',
                            'Businesses',
                            'Vues',
                          ],
                          selectedIndex: _filter,
                          onSelected: (index) => setState(() => _filter = index),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = visible[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _open(item),
                            onLongPress: () => _unsave(item),
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: fv.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: fv.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Icon(
                                      Icons.bookmark_rounded,
                                      color: FirstVueColors.gold,
                                      size: 20,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    item.contentType ==
                                            SavedContentType.business
                                        ? Icons.storefront_outlined
                                        : Icons.photo_outlined,
                                    color: FirstVueColors.gold,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: fv.primaryText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item.subtitle != null)
                                    Text(
                                      item.subtitle!,
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
