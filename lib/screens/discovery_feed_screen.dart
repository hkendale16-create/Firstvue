import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../config/app_config.dart';
import '../config/feature_flags.dart';
import '../models/publish_destination.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/discovery_feed_service.dart';
import '../services/live_mode_preference.dart';
import '../services/saved_items_service.dart';
import '../services/vue_featured_rotation.dart';
import '../services/vue_tab_preference.dart';
import '../theme/firstvue_theme.dart';
import '../utils/scroll_load_more_gate.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/fv_ui.dart';
import '../widgets/social_rich_text.dart';
import '../widgets/tutorial_targets.dart';
import '../widgets/vue_live_mode_switch.dart';
import '../widgets/vue_mosaic_layout.dart';
import '../widgets/vue_mosaic_view.dart';
import 'create_post_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'full_screen_media_viewer.dart';
import 'live_home_shell_screen.dart';
import 'member_public_profile_screen.dart';
import 'post_detail_screen.dart';

/// Keep a previously painted VUE mosaic when a reset returns zero usable items
/// (sign failures / timeouts). Used by [DiscoveryFeedScreen] and unit tests.
bool shouldRetainVueItems({
  required bool reset,
  required int previousCount,
  required int incomingCount,
}) {
  return reset && incomingCount == 0 && previousCount > 0;
}

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late Future<List<DiscoveryFeedItem>> _feedFuture;
  List<DiscoveryFeedItem> _items = const [];
  VueFeedMode _mode = VueTabPreference.current;
  FirstVueExperienceMode _experienceMode = LiveModePreference.current;
  String? _error;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _hasMore = true;
  int _loadGeneration = 0;
  int _loadMoreFailures = 0;
  double _sessionSeed = 0;
  final _loadMoreGate = ScrollLoadMoreGate(thresholdPx: 480);
  static const _maxLoadMoreFailures = 3;

  bool get _liveModeActive =>
      FeatureFlags.liveModeEnabled &&
      _experienceMode == FirstVueExperienceMode.live;

  @override
  void initState() {
    super.initState();
    _mode = VueTabPreference.current;
    _experienceMode = LiveModePreference.current;
    _feedFuture = _bootstrap();
  }

  Future<List<DiscoveryFeedItem>> _bootstrap() async {
    final storedTab = await VueTabPreference.load();
    final storedExperience = FeatureFlags.liveModeEnabled
        ? await LiveModePreference.load()
        : FirstVueExperienceMode.vue;
    if (!mounted) return _loadFeed(reset: true);
    if (storedTab != _mode || storedExperience != _experienceMode) {
      setState(() {
        _mode = storedTab;
        _experienceMode = storedExperience;
      });
    }
    // Avoid feed work while sitting on the LIVE shell.
    if (_liveModeActive) return _items;
    return _loadFeed(reset: true);
  }

  Future<void> _setExperienceMode(FirstVueExperienceMode next) async {
    if (next == _experienceMode) return;
    setState(() => _experienceMode = next);
    await LiveModePreference.save(next);
    if (!mounted) return;
    if (next == FirstVueExperienceMode.vue && _items.isEmpty) {
      setState(() {
        _refreshing = true;
        _error = null;
        _hasMore = true;
        _loadMoreFailures = 0;
      });
      _feedFuture = _loadFeed(reset: true).whenComplete(() {
        if (mounted) setState(() => _refreshing = false);
      });
    }
  }

  Future<List<DiscoveryFeedItem>> _loadFeed({
    bool reset = false,
    int limit = 30,
  }) async {
    final generation = ++_loadGeneration;
    if (reset || _sessionSeed == 0) {
      _sessionSeed = DateTime.now().microsecondsSinceEpoch.toDouble();
    }
    try {
      final exclude = reset
          ? const <String>{}
          : _items.map((item) => item.mediaId).toSet();
      final items = await DiscoveryFeedService.fetchFeed(
        mode: _mode,
        limit: limit,
        offset: 0,
        excludeMediaIds: exclude,
        seed: _sessionSeed,
      ).timeout(const Duration(seconds: 20));
      final usable = items.where((item) {
        final hasMedia = item.mediaUrl.trim().isNotEmpty;
        final hasPoster = (item.thumbnailUrl ?? '').trim().isNotEmpty;
        return hasMedia || hasPoster;
      }).toList();
      if (!mounted || generation != _loadGeneration) return usable;

      // Empty "success" (sign timeouts / missing objects) must not wipe a
      // mosaic the user is already scrolling.
      if (shouldRetainVueItems(
        reset: reset,
        previousCount: _items.length,
        incomingCount: usable.length,
      )) {
        setState(() {
          _error = null;
          _hasMore = _loadMoreFailures < _maxLoadMoreFailures;
        });
        return _items;
      }

      final arranged = reset
          ? await _arrangeFeatured(usable)
          : _appendUnique(_items, usable);
      if (!mounted || generation != _loadGeneration) return usable;
      setState(() {
        _items = arranged;
        _error = null;
        if (usable.isEmpty && !reset) {
          _loadMoreFailures += 1;
          _hasMore = _loadMoreFailures < _maxLoadMoreFailures;
          if (_hasMore) _loadMoreGate.reset();
        } else {
          _loadMoreFailures = 0;
          _hasMore = usable.length >= limit;
        }
      });
      if (reset) _loadMoreGate.reset();
      return usable;
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return const [];
      setState(() {
        // Never blank an already-visible mosaic on refresh / load-more failure.
        if (reset && _items.isEmpty) {
          _error = 'Unable to load VUE right now.';
        } else if (!reset) {
          _loadMoreFailures += 1;
          _hasMore = _loadMoreFailures < _maxLoadMoreFailures;
          if (_hasMore) _loadMoreGate.reset();
        }
      });
      rethrow;
    }
  }

  List<DiscoveryFeedItem> _appendUnique(
    List<DiscoveryFeedItem> current,
    List<DiscoveryFeedItem> incoming,
  ) {
    final seen = current.map((item) => item.mediaId).toSet();
    final merged = [...current];
    for (final item in incoming) {
      if (!seen.add(item.mediaId)) continue;
      merged.add(item);
    }
    return merged;
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _error = null;
      _hasMore = true;
      _loadMoreFailures = 0;
      _refreshing = true;
      _feedFuture = _loadFeed(reset: true);
    });
    try {
      await _feedFuture;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _refreshing || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      await _loadFeed(reset: false);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _onFeedScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final shouldLoad = _loadMoreGate.onScroll(
      pixels: notification.metrics.pixels,
      maxScrollExtent: notification.metrics.maxScrollExtent,
      canLoadMore: !_loadingMore && _hasMore,
    );
    if (shouldLoad) _loadMore();
    return false;
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

  VueFeedMode get _vueMode => _mode;

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
      final footer = _VueMediaActionFooter(
        item: item,
        onOpenProfile: () => _openProfile(item),
      );
      if (item.isVideo) {
        openFullScreenVideoPlayer(
          context,
          url: item.mediaUrl,
          title: item.businessName,
          footer: footer,
        );
      } else {
        openFullScreenImageViewer(
          context,
          items: [
            FullScreenMediaItem(
              url: item.mediaUrl,
              isVideo: false,
            ),
          ],
          title: item.businessName,
          footer: footer,
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
    final showLiveSwitch = FeatureFlags.liveModeEnabled;

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
                        if (showLiveSwitch)
                          KeyedSubtree(
                            key: TutorialTargets.vueLiveSwitch,
                            child: VueLiveModeSwitch(
                              mode: _experienceMode,
                              onChanged: _setExperienceMode,
                            ),
                          )
                        else
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
                        if (!_liveModeActive)
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
                if (_liveModeActive)
                  Expanded(
                    child: LiveHomeShellScreen(
                      onReturnToVue: () =>
                          _setExperienceMode(FirstVueExperienceMode.vue),
                    ),
                  )
                else ...[
                FvUnderlineTabs(
                  labels: const ['For You', 'Nearby', 'Trending'],
                  selectedIndex: _mode.index,
                  onSelected: (index) {
                    final next = VueFeedMode.values[index];
                    if (next == _mode) return;
                    setState(() {
                      _mode = next;
                      _error = null;
                      _hasMore = true;
                      _loadMoreFailures = 0;
                      _refreshing = true;
                      // Keep the current mosaic visible while the next mode loads.
                    });
                    _loadMoreGate.reset();
                    VueTabPreference.save(next);
                    _feedFuture = _loadFeed(reset: true).whenComplete(() {
                      if (mounted) setState(() => _refreshing = false);
                    });
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
                      // Only full-page error when there is nothing to keep on screen.
                      if (_items.isEmpty &&
                          (snapshot.hasError || _error != null)) {
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
                        onNotification: _onFeedScroll,
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
              ],
            ),
            if (!_liveModeActive)
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
                        builder: (_) => const CreatePostScreen(
                          initialDestination: PublishDestination.vue,
                        ),
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

class _VueMediaActionFooter extends StatefulWidget {
  final DiscoveryFeedItem item;
  final VoidCallback onOpenProfile;

  const _VueMediaActionFooter({
    required this.item,
    required this.onOpenProfile,
  });

  @override
  State<_VueMediaActionFooter> createState() => _VueMediaActionFooterState();
}

class _VueMediaActionFooterState extends State<_VueMediaActionFooter> {
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await SavedItemsService.isSaved(
      contentType: SavedContentType.vueMedia,
      contentId: widget.item.mediaId,
    );
    if (!mounted) return;
    setState(() => _saved = saved);
  }

  Future<void> _toggleSave() async {
    if (_busy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) return;
    }
    setState(() => _busy = true);
    final previous = _saved;
    setState(() => _saved = !_saved);
    try {
      final saved = await SavedItemsService.toggleSave(
        contentType: SavedContentType.vueMedia,
        contentId: widget.item.mediaId,
        currentlySaved: previous,
      );
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saved = previous;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this VUE right now.')),
      );
    }
  }

  void _share() {
    final item = widget.item;
    final title = item.businessName.isNotEmpty
        ? item.businessName
        : item.ownerName;
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: title,
        subtitle: item.caption,
        link: '${AppConfig.webBaseUrl}/?vue=${item.mediaId}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.item.caption.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SocialRichText(
              text: caption,
              style: const TextStyle(color: Colors.white70, height: 1.35),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _toggleSave,
                icon: Icon(
                  _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 18,
                ),
                label: Text(_saved ? 'Saved' : 'Save'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _saved ? FirstVueColors.gold : Colors.white70,
                  side: BorderSide(
                    color: _saved
                        ? FirstVueColors.gold.withValues(alpha: 0.6)
                        : Colors.white24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onOpenProfile,
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
