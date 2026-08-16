import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../config/feed_ranking_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../auth/ensure_signed_in.dart';
import '../screens/boost_post_sheet.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/community_hub_detail_screen.dart';
import '../screens/create_post_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/community_hub_service.dart';
import '../services/community_news_service.dart';
import '../services/community_service.dart';
import '../services/feed_interaction_service.dart';
import '../services/post_boost_service.dart';
import '../services/repost_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/web_safari_media.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/feed_impression_tracker.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_section_tip.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/group_circle_avatar.dart';
import '../widgets/home_community_feed_block.dart';
import '../widgets/social_chrome.dart';
import '../widgets/tutorial_targets.dart';
import '../services/onboarding_store.dart';

enum FeedsTab {
  main,
  communities,
  groups,
  trending,
  newest,
  recommended,
}

extension FeedsTabX on FeedsTab {
  String get label => switch (this) {
        FeedsTab.main => 'Main Newsfeed',
        FeedsTab.communities => 'Communities',
        FeedsTab.groups => 'Groups',
        FeedsTab.trending => 'Trending',
        FeedsTab.newest => 'New',
        FeedsTab.recommended => 'Recommended',
      };

  String get source => switch (this) {
        FeedsTab.main => FeedRankingConfig.sourceMain,
        FeedsTab.communities => FeedRankingConfig.sourceCommunities,
        FeedsTab.groups => FeedRankingConfig.sourceGroups,
        FeedsTab.trending => FeedRankingConfig.sourceTrending,
        FeedsTab.newest => FeedRankingConfig.sourceNew,
        FeedsTab.recommended => FeedRankingConfig.sourceRecommended,
      };
}

/// Dedicated Feeds page with swipeable / tappable section tabs.
class FeedsScreen extends StatefulWidget {
  final int refreshToken;

  const FeedsScreen({super.key, this.refreshToken = 0});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = FeedsTab.values;
  late final TabController _tabController;
  late final PageController _pageController;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _pageController = PageController();
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSectionTip(context, TutorialSection.feeds);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_syncing || _tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (_pageController.hasClients &&
        (_pageController.page?.round() ?? 0) != index) {
      _syncing = true;
      _pageController
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _syncing = false);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'FEEDS',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                color: FirstVueColors.gold,
                fontSize: 28,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: TutorialTargets.feedsTabs,
            child: SocialPillTabs(
              labels: _tabs.map((t) => t.label).toList(),
              selectedIndex: _tabController.index,
              onSelected: (index) {
                _tabController.index = index;
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                );
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tabs.length,
              // Adjacent-page prebuild keeps extra HTML media alive on Safari.
              allowImplicitScrolling: !webAvoidStackedMediaTabs,
              onPageChanged: (index) {
                if (_tabController.index != index) {
                  _syncing = true;
                  _tabController.index = index;
                  _syncing = false;
                }
                setState(() {});
              },
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                // Do not put refreshToken in the key — Home pull-to-refresh was
                // remounting every Feeds tab and blanking the page mid-swipe.
                return _KeepAliveTab(
                  key: ValueKey('feeds-${tab.name}'),
                  child: _FeedsTabBody(
                    tab: tab,
                    refreshToken: widget.refreshToken,
                  ),
                );
              },
            ),
          ),
          // Keep theme divider under page for visual continuity.
          Divider(height: 1, color: fv.divider.withValues(alpha: 0)),
        ],
      ),
    );
  }
}

/// Keeps off-screen Feeds pages alive so fast swipes do not blank/reload.
/// Disabled on web — keeping every Feeds section mounted stacks platform views
/// until iOS Safari reports "A problem repeatedly occurred".
class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({super.key, required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => !webAvoidStackedMediaTabs;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _FeedsTabBody extends StatelessWidget {
  final FeedsTab tab;
  final int refreshToken;

  const _FeedsTabBody({
    required this.tab,
    required this.refreshToken,
  });

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      FeedsTab.main => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            HomeCommunityFeedBlock(
              refreshToken: refreshToken,
              borderlessComposer: true,
            ),
          ],
        ),
      FeedsTab.communities => _CommunitiesDirectoryAndFeed(
          refreshToken: refreshToken,
        ),
      FeedsTab.groups => _GroupsDirectoryAndFeed(
          refreshToken: refreshToken,
        ),
      FeedsTab.trending => FeedsPostsList(
          refreshToken: refreshToken,
          source: tab.source,
          emptyTitle: 'Nothing trending yet',
          emptySubtitle: 'Engage with posts to build momentum here.',
          useCursor: true,
          loader: ({
            int limit = 20,
            CommunityNewsPost? cursor,
            Iterable<String> excludeIds = const [],
          }) {
            return CommunityNewsService.fetchTrendingFeed(
              limit: limit,
              windowHours: FeedRankingConfig.trendingWindow.inHours,
              excludeIds: excludeIds,
            );
          },
        ),
      FeedsTab.newest => FeedsPostsList(
          refreshToken: refreshToken,
          source: tab.source,
          emptyTitle: 'No new posts',
          emptySubtitle: 'Fresh posts will appear here in order.',
          useCursor: true,
          loader: ({
            int limit = 20,
            CommunityNewsPost? cursor,
            Iterable<String> excludeIds = const [],
          }) {
            return CommunityNewsService.fetchNewFeed(
              limit: limit,
              beforeCreatedAt: cursor?.createdAt,
              beforeId: cursor?.id,
            );
          },
        ),
      FeedsTab.recommended => FeedsPostsList(
          refreshToken: refreshToken,
          source: tab.source,
          emptyTitle: 'No recommendations yet',
          emptySubtitle:
              'Follow people, join groups, and interact to personalize this feed.',
          useCursor: true,
          loader: ({
            int limit = 20,
            CommunityNewsPost? cursor,
            Iterable<String> excludeIds = const [],
          }) {
            return CommunityNewsService.fetchRecommendedFeed(
              limit: limit,
              excludeIds: excludeIds,
            );
          },
        ),
    };
  }
}

typedef FeedsLoader = Future<List<CommunityNewsPost>> Function({
  int limit,
  CommunityNewsPost? cursor,
  Iterable<String> excludeIds,
});

class FeedsPostsList extends StatefulWidget {
  final int refreshToken;
  final String source;
  final String emptyTitle;
  final String emptySubtitle;
  final FeedsLoader loader;
  final bool useCursor;
  final Widget? header;

  const FeedsPostsList({
    super.key,
    required this.refreshToken,
    required this.source,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.loader,
    this.useCursor = false,
    this.header,
  });

  @override
  State<FeedsPostsList> createState() => _FeedsPostsListState();
}

class _FeedsPostsListState extends State<FeedsPostsList> {
  final List<CommunityNewsPost> _posts = [];
  final Set<String> _seenIds = {};
  Set<String> _reposted = {};
  Set<String> _boostedIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Set<String> _actionBusy = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant FeedsPostsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.source != widget.source) {
      _reload();
    }
  }

  Future<void> _reload() async {
    final keepVisible = _posts.isNotEmpty;
    setState(() {
      if (!keepVisible) _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final posts = await widget.loader(limit: FeedRankingConfig.defaultPageSize);
      final boosted = await PostBoostService.fetchActiveBoostedPostIds();
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _seenIds
          ..clear()
          ..addAll(posts.map((p) => p.id));
        _reposted = {
          for (final post in posts)
            if (post.repostedByMe) post.id,
        };
        _boostedIds = boosted;
        _loading = false;
        _hasMore = posts.length >= FeedRankingConfig.defaultPageSize;
      });
    } catch (error) {
      CommunityNewsService.logFeedError(error, context: 'FeedsPostsList');
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!keepVisible) {
          _error = 'Could not load this feed.';
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final cursor = widget.useCursor ? _posts.last : null;
      final more = await widget.loader(
        limit: FeedRankingConfig.defaultPageSize,
        cursor: cursor,
        excludeIds: _seenIds,
      );
      final fresh = more.where((p) => _seenIds.add(p.id)).toList();
      if (!mounted) return;
      setState(() {
        _posts.addAll(fresh);
        _reposted = {
          ..._reposted,
          for (final post in fresh)
            if (post.repostedByMe) post.id,
        };
        _hasMore = more.length >= FeedRankingConfig.defaultPageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        // Keep "See more" available for a manual retry.
        _hasMore = true;
      });
    }
  }

  Future<void> _ensureSignedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return;
    await ensureSignedIn(context);
  }

  Future<void> _withBusy(String postId, Future<void> Function() action) async {
    if (_actionBusy.contains(postId)) return;
    _actionBusy.add(postId);
    try {
      await action();
    } finally {
      _actionBusy.remove(postId);
    }
  }

  Future<void> _spark(int index) async {
    final post = _posts[index];
    await _withBusy(post.id, () async {
      final previous = post;
      final optimistic = post.copyWith(
        sparkedByMe: !post.sparkedByMe,
        sparkCount: post.sparkCount + (post.sparkedByMe ? -1 : 1),
      );
      setState(() => _posts[index] = optimistic);
      try {
        final updated = await CommunityNewsService.toggleSpark(post);
        if (!mounted) return;
        setState(() => _posts[index] = updated);
        FeedInteractionService.record(
          postId: post.id,
          interactionType: updated.sparkedByMe ? 'spark' : 'unspark',
          sourceTab: widget.source,
        );
      } on AuthException {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        await _ensureSignedIn();
      } catch (_) {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
      }
    });
  }

  Future<void> _setReaction(int index, PostReactionType type) async {
    final post = _posts[index];
    await _withBusy(post.id, () async {
      final previous = post;
      final togglingOff = post.myReaction == type;
      final optimistic = post.copyWith(
        sparkedByMe: !togglingOff,
        myReactionType: togglingOff ? null : type.value,
        sparkCount:
            post.sparkCount + (togglingOff ? -1 : (post.sparkedByMe ? 0 : 1)),
      );
      setState(() => _posts[index] = optimistic);
      try {
        final updated = await CommunityNewsService.setReaction(post, type);
        if (!mounted) return;
        setState(() => _posts[index] = updated);
        FeedInteractionService.record(
          postId: post.id,
          interactionType: updated.sparkedByMe ? 'spark' : 'unspark',
          sourceTab: widget.source,
        );
      } on AuthException {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        await _ensureSignedIn();
      } catch (_) {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
      }
    });
  }

  Future<void> _save(int index) async {
    final post = _posts[index];
    await _withBusy(post.id, () async {
      final previous = post;
      setState(() => _posts[index] = post.copyWith(savedByMe: !post.savedByMe));
      try {
        final updated = await CommunityNewsService.toggleSave(post);
        if (!mounted) return;
        setState(() => _posts[index] = updated);
        FeedInteractionService.record(
          postId: post.id,
          interactionType: updated.savedByMe ? 'save' : 'unsave',
          sourceTab: widget.source,
        );
      } on AuthException {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        await _ensureSignedIn();
      } catch (_) {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
      }
    });
  }

  Future<void> _repost(int index) async {
    final post = _posts[index];
    await _withBusy(post.id, () async {
      final was = _reposted.contains(post.id);
      setState(() {
        _reposted = was
            ? _reposted.where((id) => id != post.id).toSet()
            : {..._reposted, post.id};
        _posts[index] = post.copyWith(
          repostCount: post.repostCount + (was ? -1 : 1),
        );
      });
      try {
        await RepostService.toggleRepost(
          post.id,
          currentlyReposted: was,
        );
        FeedInteractionService.record(
          postId: post.id,
          interactionType: 'repost',
          sourceTab: widget.source,
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _reposted = was
              ? {..._reposted, post.id}
              : _reposted.where((id) => id != post.id).toSet();
          _posts[index] = post;
        });
      }
    });
  }

  void _share(CommunityNewsPost post) {
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: post.authorName,
        subtitle: post.body,
        link: '${AppConfig.webBaseUrl}/?post=${post.id}',
      ),
    );
    FeedInteractionService.record(
      postId: post.id,
      interactionType: 'share',
      sourceTab: widget.source,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FirstVueRefreshScaffold(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 12),
          ],
          if (_loading && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: FirstVueColors.teal),
              ),
            )
          else if (_error != null && _posts.isEmpty)
            _FeedStateMessage(
              title: _error!,
              actionLabel: 'Retry',
              onAction: _reload,
            )
          else if (_posts.isEmpty)
            _FeedStateMessage(
              title: widget.emptyTitle,
              subtitle: widget.emptySubtitle,
            )
          else ...[
            for (var i = 0; i < _posts.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              FeedImpressionTracker(
                postId: _posts[i].id,
                feedSource: widget.source,
                child: CommunityNewsPostCard(
                  post: _posts[i],
                  style: CommunityNewsPostCardStyle.timeline,
                  onTap: () => CommunityNewsPostDetailSheet.show(
                    context,
                    postId: _posts[i].id,
                    initialPost: _posts[i],
                  ),
                  onAuthorTap: _posts[i].authorId.isNotEmpty
                      ? () => openMemberProfile(
                            context,
                            profileId: _posts[i].authorId,
                            displayName: _posts[i].authorName,
                          )
                      : null,
                  onSpark: () => _spark(i),
                  onSetReaction: (type) => _setReaction(i, type),
                  onSave: () => _save(i),
                  onComment: () {
                    FeedCommentsSheet.show(
                      context,
                      mediaId: _posts[i].commentsMediaId,
                      businessName: _posts[i].authorName,
                    );
                    FeedInteractionService.record(
                      postId: _posts[i].id,
                      interactionType: 'comment',
                      sourceTab: widget.source,
                    );
                  },
                  onRepost: () => _repost(i),
                  onShare: () => _share(_posts[i]),
                  onDelete: _posts[i].isMine
                      ? () async {
                          final deleted =
                              await confirmDeleteNewsPost(context, _posts[i]);
                          if (!deleted || !mounted) return;
                          setState(() => _posts.removeAt(i));
                        }
                      : null,
                  onBoost: _posts[i].isMine
                      ? () => openBoostPostFlow(context, _posts[i])
                      : null,
                  isPromoted: _boostedIds.contains(_posts[i].id),
                  repostedByMe: _reposted.contains(_posts[i].id),
                ),
              ),
            ],
            if (_hasMore) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: Text(_loadingMore ? 'Loading…' : 'See more posts'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FeedStateMessage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _FeedStateMessage({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: fv.secondaryText, height: 1.35),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _CommunitiesDirectoryAndFeed extends StatefulWidget {
  final int refreshToken;
  const _CommunitiesDirectoryAndFeed({required this.refreshToken});

  @override
  State<_CommunitiesDirectoryAndFeed> createState() =>
      _CommunitiesDirectoryAndFeedState();
}

class _CommunitiesDirectoryAndFeedState
    extends State<_CommunitiesDirectoryAndFeed> {
  List<CommunityHub> _hubs = const [];
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CommunitiesDirectoryAndFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final hubs = await CommunityHubService.fetchHubs(limit: 40);
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted) return;
    setState(() {
      _hubs = hubs;
      _loading = false;
    });
    // Prefetch affiliations for "joined/created" filters when signed in.
    if (me != null) {
      // no-op placeholder — filter uses creator / leader fields on hub.
    }
  }

  List<CommunityHub> get _filtered {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return switch (_filter) {
      'created' => me == null
          ? const []
          : _hubs
              .where((h) =>
                  h.createdByProfileId == me || h.leaderUserId == me)
              .toList(),
      'newest' => [..._hubs]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      'local' => _hubs
          .where((h) =>
              (h.city?.trim().isNotEmpty ?? false) ||
              (h.state?.trim().isNotEmpty ?? false))
          .toList(),
      'category' => _hubs
          .where((h) => h.category?.trim().isNotEmpty ?? false)
          .toList(),
      _ => _hubs,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return FeedsPostsList(
      refreshToken: widget.refreshToken,
      source: FeedRankingConfig.sourceCommunities,
      emptyTitle: 'No community posts yet',
      emptySubtitle: 'Join communities to see their shared feeds here.',
      loader: ({
        int limit = 20,
        CommunityNewsPost? cursor,
        Iterable<String> excludeIds = const [],
      }) {
        return CommunityNewsService.fetchAllCommunitiesFeed(limit: limit);
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'COMMUNITIES',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) =>
                          const CommunitiesScreen(initialTabIndex: 1),
                    ),
                  );
                },
                child: const Text('Browse all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const [
                ('all', 'All'),
                ('created', 'Created'),
                ('local', 'Local'),
                ('category', 'Category'),
                ('newest', 'Newest'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _filter == entry.$1,
                  onSelected: (_) => setState(() => _filter = entry.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(color: FirstVueColors.teal)
          else if (_filtered.isEmpty)
            Text(
              'No communities match this filter.',
              style: TextStyle(color: fv.secondaryText),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final hub = _filtered[index];
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => CommunityHubDetailScreen(
                            hubId: hub.id,
                            initialHub: hub,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 88,
                      child: Column(
                        children: [
                          GroupCircleAvatar(
                            imageUrl: hub.coverUrl ?? hub.imageUrl,
                            size: 56,
                            fallbackIcon: Icons.hub_outlined,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hub.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: fv.primaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupsDirectoryAndFeed extends StatefulWidget {
  final int refreshToken;
  const _GroupsDirectoryAndFeed({required this.refreshToken});

  @override
  State<_GroupsDirectoryAndFeed> createState() =>
      _GroupsDirectoryAndFeedState();
}

class _GroupsDirectoryAndFeedState extends State<_GroupsDirectoryAndFeed> {
  List<Community> _groups = const [];
  String _filter = 'joined';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _GroupsDirectoryAndFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final yours = await CommunityService.fetchYourCommunities(limit: 40);
    final nearby = await CommunityService.fetchNearbyCommunities(limit: 24);
    if (!mounted) return;
    setState(() {
      _groups = _filter == 'local' ? nearby : yours;
      if (_filter == 'all' || _filter == 'newest' || _filter == 'category') {
        final map = <String, Community>{
          for (final g in [...yours, ...nearby]) g.id: g,
        };
        _groups = map.values.toList();
        if (_filter == 'newest') {
          _groups = [..._groups]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else if (_filter == 'category') {
          _groups = _groups
              .where((g) => g.category?.trim().isNotEmpty ?? false)
              .toList();
        }
      } else if (_filter == 'created') {
        final me = Supabase.instance.client.auth.currentUser?.id;
        _groups = yours.where((g) => g.creatorId == me).toList();
      } else if (_filter == 'joined') {
        _groups = yours;
      } else if (_filter == 'local') {
        _groups = nearby;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return FeedsPostsList(
      refreshToken: widget.refreshToken,
      source: FeedRankingConfig.sourceGroups,
      emptyTitle: 'No group posts yet',
      emptySubtitle: 'Join or follow groups to fill this feed.',
      loader: ({
        int limit = 20,
        CommunityNewsPost? cursor,
        Iterable<String> excludeIds = const [],
      }) {
        return CommunityNewsService.fetchCommunityFeed(limit: limit);
      },
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'GROUPS',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) =>
                          const CommunitiesScreen(initialTabIndex: 0),
                    ),
                  );
                },
                child: const Text('Browse all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const [
                ('joined', 'Joined'),
                ('created', 'Created'),
                ('local', 'Local'),
                ('category', 'Category'),
                ('newest', 'Newest'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _filter == entry.$1,
                  onSelected: (_) {
                    setState(() => _filter = entry.$1);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(color: FirstVueColors.teal)
          else if (_groups.isEmpty)
            Text(
              'No groups match this filter.',
              style: TextStyle(color: fv.secondaryText),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final group = _groups[index];
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => CommunityDetailScreen(
                            communityId: group.id,
                            initialCommunity: group,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 88,
                      child: Column(
                        children: [
                          GroupCircleAvatar(
                            imageUrl: group.imageUrl,
                            size: 56,
                            fallbackIcon: Icons.groups_rounded,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            group.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: fv.primaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await _ensureComposer(context);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Create a post'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureComposer(BuildContext context) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
    }
    if (Supabase.instance.client.auth.currentUser == null) return;
    if (!context.mounted) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const CreatePostScreen()),
    );
  }
}
