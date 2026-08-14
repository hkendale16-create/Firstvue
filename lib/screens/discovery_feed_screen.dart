import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/discovery_feed_service.dart';
import '../services/vue_featured_rotation.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/fv_ui.dart';
import '../widgets/vue_mosaic_layout.dart';
import '../widgets/vue_mosaic_view.dart';
import 'create_post_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'full_screen_media_viewer.dart';
import 'member_public_profile_screen.dart';
import 'post_detail_screen.dart';

enum _FeedMode { forYou, nearby, trending }

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late Future<List<DiscoveryFeedItem>> _feedFuture;
  List<DiscoveryFeedItem> _items = const [];
  _FeedMode _mode = _FeedMode.forYou;
  String? _error;
  bool _loadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed(reset: true);
  }

  Future<List<DiscoveryFeedItem>> _loadFeed({
    bool reset = false,
    int limit = 30,
  }) async {
    final mode = switch (_mode) {
      _FeedMode.forYou => VueFeedMode.forYou,
      _FeedMode.nearby => VueFeedMode.nearby,
      _FeedMode.trending => VueFeedMode.trending,
    };
    try {
      final items = await DiscoveryFeedService.fetchFeed(
        mode: mode,
        limit: limit,
        offset: reset ? 0 : _items.length,
      ).timeout(const Duration(seconds: 20));
      final usable = items
          .where((item) => item.mediaUrl.trim().isNotEmpty)
          .toList();
      if (!mounted) return usable;
      final arranged = reset
          ? await _arrangeFeatured(usable)
          : [..._items, ...usable];
      if (!mounted) return usable;
      setState(() {
        _items = arranged;
        _error = null;
        _hasMore = usable.length >= limit;
      });
      return usable;
    } catch (error) {
      if (!mounted) return const [];
      setState(() {
        if (reset) _items = const [];
        _error = 'Unable to load VUE right now.';
      });
      rethrow;
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _error = null;
      _hasMore = true;
      _feedFuture = _loadFeed(reset: true);
    });
    try {
      await _feedFuture;
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _loadFeed(reset: false);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<List<DiscoveryFeedItem>> _arrangeFeatured(
    List<DiscoveryFeedItem> ranked,
  ) async {
    final width = mounted ? MediaQuery.sizeOf(context).width : 390.0;
    final columns = _crossAxisCount(width);
    final cells = buildVueMosaic(itemCount: ranked.length, columns: columns);
    final lastCreator = await VueFeaturedRotation.lastCreator(_vueMode);
    final arranged = assignVueMosaicItems(
      ranked: ranked,
      cells: cells,
      creatorId: (item) => item.creatorId,
      lastFeaturedCreatorId: lastCreator,
    );
    final featuredCreator = leadingFeaturedCreatorId(
      items: arranged,
      cells: cells,
      creatorId: (item) => item.creatorId,
    );
    if (featuredCreator != null) {
      await VueFeaturedRotation.remember(_vueMode, featuredCreator);
    }
    return arranged;
  }

  VueFeedMode get _vueMode => switch (_mode) {
    _FeedMode.forYou => VueFeedMode.forYou,
    _FeedMode.nearby => VueFeedMode.nearby,
    _FeedMode.trending => VueFeedMode.trending,
  };

  void _openMedia(DiscoveryFeedItem item) {
    if (item.newsPostId != null) {
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => PostDetailScreen(postId: item.newsPostId!),
        ),
      );
      return;
    }
    if (item.mediaUrl.startsWith('http')) {
      if (item.isVideo) {
        openFullScreenVideoPlayer(
          context,
          url: item.mediaUrl,
          title: item.businessName,
        );
      } else {
        openFullScreenImageViewer(
          context,
          items: [
            FullScreenMediaItem(
              url: item.mediaUrl,
              isVideo: false,
              caption: item.caption,
            ),
          ],
          title: item.businessName,
        );
      }
      return;
    }
    _openProfile(item);
  }

  void _openProfile(DiscoveryFeedItem item) {
    DiscoveryFeedService.recordProfileTap(item);
    if (item.isMember) {
      openMemberProfile(
        context,
        profileId: item.ownerId,
        displayName: item.ownerName,
      );
      return;
    }
    if (item.businessId.isNotEmpty) {
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: item.businessId),
        ),
      );
    }
  }

  int _crossAxisCount(double width) {
    if (width >= 1100) return 5;
    if (width >= 840) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final width = MediaQuery.sizeOf(context).width;
    final columns = _crossAxisCount(width);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: fv.background,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          'VUE',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            color: FirstVueColors.gold,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Search',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Search coming soon.'),
                                ),
                              );
                            },
                            icon: Icon(Icons.search, color: fv.primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FvUnderlineTabs(
                  labels: const ['For You', 'Nearby', 'Trending'],
                  selectedIndex: _mode.index,
                  onSelected: (index) {
                    final next = _FeedMode.values[index];
                    if (next == _mode) return;
                    setState(() => _mode = next);
                    _feedFuture = _loadFeed(reset: true);
                  },
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: FutureBuilder<List<DiscoveryFeedItem>>(
                    future: _feedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          _items.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: FirstVueColors.gold,
                          ),
                        );
                      }
                      if (snapshot.hasError || _error != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error ?? 'Unable to load VUE right now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: fv.secondaryText),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _refreshFeed,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (_items.isEmpty) {
                        return Center(
                          child: Text(
                            'No photos or videos to show yet.',
                            style: TextStyle(color: fv.secondaryText),
                          ),
                        );
                      }
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.metrics.pixels >
                              notification.metrics.maxScrollExtent - 480) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: FirstVueRefreshScaffold(
                          onRefresh: _refreshFeed,
                          child: VueMosaicView(
                            items: _items,
                            columns: columns,
                            loadingMore: _loadingMore,
                            padding: EdgeInsets.fromLTRB(
                              FvUi.gutter,
                              0,
                              FvUi.gutter,
                              88 + bottomInset,
                            ),
                            onOpen: _openMedia,
                            onOpenProfile: _openProfile,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16 + bottomInset,
              child: Semantics(
                button: true,
                label: 'Create a Vue',
                child: FloatingActionButton(
                  heroTag: 'vue-create-fab',
                  onPressed: () {
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => const CreatePostScreen(),
                      ),
                    );
                  },
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  child: const Icon(Icons.add, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
