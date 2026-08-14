import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/discovery_feed_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/explore_grid_video.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/fv_ui.dart';
import '../widgets/social_chrome.dart';
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
      setState(() {
        _items = reset ? usable : [..._items, ...usable];
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
                          child: GridView.builder(
                            padding: EdgeInsets.fromLTRB(
                              FvUi.gutter,
                              0,
                              FvUi.gutter,
                              88 + bottomInset,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: FvUi.gutter,
                                  crossAxisSpacing: FvUi.gutter,
                                  childAspectRatio: 0.72,
                                ),
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            itemBuilder: (_, index) {
                              if (index >= _items.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: FirstVueColors.gold,
                                    ),
                                  ),
                                );
                              }
                              final item = _items[index];
                              final featured = index == 0 && columns >= 3;
                              return _VueMosaicTile(
                                item: item,
                                featured: featured,
                                onOpen: () => _openMedia(item),
                                onOpenProfile: () => _openProfile(item),
                              );
                            },
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

class _VueMosaicTile extends StatelessWidget {
  final DiscoveryFeedItem item;
  final bool featured;
  final VoidCallback onOpen;
  final VoidCallback onOpenProfile;

  const _VueMosaicTile({
    required this.item,
    required this.featured,
    required this.onOpen,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final handle = item.isMember
        ? socialHandleFromName(item.ownerName)
        : socialHandleFromName(item.businessName);
    final categoryLine = [
      item.businessType,
      if (item.services.isNotEmpty) item.services.first,
    ].where((p) => p.trim().isNotEmpty).take(2).join(' · ');
    final thumbUrl = (item.thumbnailUrl?.trim().isNotEmpty == true)
        ? item.thumbnailUrl!
        : item.mediaUrl;
    final live = item.liveNow;

    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(featured ? 4 : 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isVideo &&
                (item.thumbnailUrl == null || item.thumbnailUrl!.isEmpty))
              ExploreGridVideo(
                url: item.mediaUrl,
                thumbnailUrl: thumbUrl.startsWith('http') ? thumbUrl : null,
                onTap: onOpen,
              )
            else if (thumbUrl.startsWith('http'))
              Image.network(
                thumbUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: fv.elevatedSurface,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: fv.mutedIcon,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: fv.elevatedSurface,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: FirstVueColors.gold,
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              ColoredBox(
                color: fv.elevatedSurface,
                child: Icon(Icons.photo_outlined, color: fv.mutedIcon),
              ),
            if (item.isVideo) ...[
              const Positioned(
                top: 8,
                left: 8,
                child: Icon(
                  Icons.movie_filter_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              if (item.durationLabel != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Text(
                    item.durationLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onOpenProfile,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: fv.elevatedSurface,
                        backgroundImage:
                            item.avatarUrl != null &&
                                item.avatarUrl!.startsWith('http')
                            ? NetworkImage(item.avatarUrl!)
                            : null,
                        child:
                            item.avatarUrl == null ||
                                !item.avatarUrl!.startsWith('http')
                            ? Icon(
                                item.isMember
                                    ? Icons.person_rounded
                                    : Icons.storefront_rounded,
                                size: 12,
                                color: FirstVueColors.gold,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onOpenProfile,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    handle.startsWith('@')
                                        ? handle
                                        : '@$handle',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                if (item.verified) ...[
                                  const SizedBox(width: 3),
                                  const Icon(
                                    Icons.verified,
                                    color: FirstVueColors.gold,
                                    size: 12,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (live)
                            const Text(
                              '● Live now',
                              style: TextStyle(
                                color: FirstVueColors.teal,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (categoryLine.isNotEmpty)
                            Text(
                              categoryLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .78),
                                fontSize: 10,
                              ),
                            ),
                        ],
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
}
