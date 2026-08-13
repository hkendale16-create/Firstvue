import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/saved_items_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  late Future<List<SavedItem>> _future;

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

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'FAVORITES',
                    style: TextStyle(
                      fontFamily: 'CormorantGaramond',
                      color: fv.primaryText,
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  );
                }
                final item = items[index - 1];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(19),
                    onTap: () => _open(item),
                    onLongPress: () => _unsave(item),
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: fv.surface,
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: FirstVueColors.gold.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.contentType == SavedContentType.business
                                ? Icons.storefront_outlined
                                : Icons.bookmark_rounded,
                            color: FirstVueColors.gold,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: fv.primaryText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.subtitle != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: fv.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
