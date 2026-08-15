import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../auth/ensure_signed_in.dart';
import '../screens/create_post_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/story_composer_screen.dart';
import '../services/community_news_service.dart';
import '../services/feed_interaction_service.dart';
import '../services/profile_media_service.dart';
import '../services/repost_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/app_environment.dart';
import '../widgets/firstvue_share_sheet.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'feed_impression_tracker.dart';
import 'profile_avatar_thumbnail.dart';
import 'stories_tray.dart';

/// Facebook-style composer + news feed for the Home Communities container.
class HomeCommunityFeedBlock extends StatefulWidget {
  const HomeCommunityFeedBlock({
    super.key,
    this.refreshToken = 0,
    this.maxPosts = 20,
    this.borderlessComposer = false,
    this.showTitle = true,
  });

  final int refreshToken;
  final int maxPosts;
  final bool borderlessComposer;
  final bool showTitle;

  @override
  State<HomeCommunityFeedBlock> createState() => _HomeCommunityFeedBlockState();
}

class _HomeCommunityFeedBlockState extends State<HomeCommunityFeedBlock> {
  List<CommunityNewsPost> _posts = const [];
  Set<String> _repostedPostIds = const {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _avatarUrl;
  String _displayName = 'you';
  int _feedLimit = 20;
  /// Stable for this session so "load more" does not reshuffle the whole feed.
  late double _rankSeed;
  RealtimeChannel? _newsChannel;
  int _storiesRefresh = 0;

  @override
  void initState() {
    super.initState();
    _feedLimit = widget.maxPosts;
    _rankSeed = DateTime.now().millisecondsSinceEpoch.toDouble();
    _bootstrap();
    _subscribeToNewsFeed();
  }

  @override
  void didUpdateWidget(covariant HomeCommunityFeedBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _rankSeed = DateTime.now().millisecondsSinceEpoch.toDouble();
      _feedLimit = widget.maxPosts;
      _hasMore = true;
      _loadFeed();
    }
  }

  @override
  void dispose() {
    _newsChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToNewsFeed() {
    if (isWidgetTestBinding) return;
    _newsChannel?.unsubscribe();
    _newsChannel = Supabase.instance.client
        .channel('home-community-feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_news_posts',
          callback: (payload) async {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            if (record['status'] != 'approved') return;
            final postId = record['id'] as String?;
            if (postId == null) return;
            if (_posts.any((post) => post.id == postId)) return;
            final post = await CommunityNewsService.fetchPostById(postId);
            if (post == null || !mounted) return;
            if (!post.publishDestination.appearsOnHome) return;
            setState(() {
              _posts = [
                post,
                for (final existing in _posts)
                  if (existing.id != post.id) existing,
              ];
            });
          },
        )
        .subscribe();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadProfileHint(), _loadFeed()]);
  }

  Future<void> _loadProfileHint() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rowFuture = Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final imagesFuture = ProfileMediaService.fetchProfileImagesForUser(
        user.id,
      );
      final row = await rowFuture;
      final images = await imagesFuture;
      if (!mounted) return;
      final name = (row?['display_name'] as String?)?.trim();
      final avatar = images.avatar?.signedUrl;
      setState(() {
        if (name != null && name.isNotEmpty) _displayName = name;
        if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
      });
    } catch (_) {
      // Non-blocking.
    }
  }

  Future<void> _loadFeed({bool silent = false, bool reshuffle = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    if (reshuffle) {
      _rankSeed = DateTime.now().millisecondsSinceEpoch.toDouble();
      _feedLimit = widget.maxPosts;
      _hasMore = true;
    }
    try {
      // Ranked main Newsfeed: recency + unseen + relevance + controlled variety.
      // Seed is stable across load-more so scrolling does not reshuffle posts.
      final posts = await CommunityNewsService.fetchRankedMainFeed(
        limit: _feedLimit,
        seed: _rankSeed,
      );
      final postIds = posts.map((p) => p.id).toList();
      final reposted = await RepostService.fetchMyRepostedIds(postIds);
      final repostCounts = await RepostService.fetchRepostCounts(postIds);
      if (!mounted) return;
      setState(() {
        _posts = posts
            .map((p) => p.copyWith(repostCount: repostCounts[p.id] ?? 0))
            .toList(growable: false);
        _repostedPostIds = reposted;
        _loading = false;
        _error = null;
        _hasMore = posts.length >= _feedLimit;
      });
    } catch (error) {
      CommunityNewsService.logFeedError(
        error,
        context: 'HomeCommunityFeedBlock.load',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _posts.isEmpty) {
          _error = 'Could not load community posts.';
        }
        if (silent) {
          // Keep the button so the user can retry instead of permanently
          // ending pagination after a transient network/sign failure.
          _hasMore = true;
        }
      });
    }
  }

  Future<void> _ensureSignedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return;
    await ensureSignedIn(context);
  }

  Future<bool> _ensureSignedInForAction() async {
    await _ensureSignedIn();
    return Supabase.instance.client.auth.currentUser != null;
  }

  Future<void> _openCreatePost() async {
    await _ensureSignedIn();
    if (Supabase.instance.client.auth.currentUser == null || !mounted) return;
    final created = await Navigator.push<CommunityNewsPost>(
      context,
      FirstVuePageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == null || !mounted) return;
    if (!created.publishDestination.appearsOnHome) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Posted to VUE.')));
      return;
    }
    setState(() {
      _posts = [
        created,
        for (final post in _posts)
          if (post.id != created.id) post,
      ];
    });
  }

  Future<void> _openStoryComposer() async {
    await _ensureSignedIn();
    if (Supabase.instance.client.auth.currentUser == null || !mounted) return;
    final created = await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const StoryComposerScreen()),
    );
    if (created != null && mounted) {
      setState(() => _storiesRefresh++);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _feedLimit += 20;
    });
    await _loadFeed(silent: true);
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!await _ensureSignedInForAction()) return;
      if (!mounted || index >= _posts.length) return;
    }
    final post = _posts[index];
    final previous = post;
    final willSpark = !post.sparkedByMe;
    final optimistic = post.copyWith(
      sparkedByMe: willSpark,
      sparkCount: post.sparkCount + (willSpark ? 1 : -1),
    );
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index) optimistic else _posts[i],
      ];
    });
    try {
      final updated = await CommunityNewsService.toggleSpark(post);
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) updated else _posts[i],
        ];
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      if (await _ensureSignedInForAction() && mounted) {
        await _sparkPost(index);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
    }
  }

  Future<void> _savePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!await _ensureSignedInForAction()) return;
      if (!mounted || index >= _posts.length) return;
    }
    final post = _posts[index];
    final previous = post;
    final optimistic = post.copyWith(savedByMe: !post.savedByMe);
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index) optimistic else _posts[i],
      ];
    });
    try {
      final updated = await CommunityNewsService.toggleSave(post);
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) updated else _posts[i],
        ];
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      if (await _ensureSignedInForAction() && mounted) {
        await _savePost(index);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
    }
  }

  Future<void> _repostPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasReposted = _repostedPostIds.contains(post.id);
    setState(() {
      _repostedPostIds = wasReposted
          ? _repostedPostIds.where((id) => id != post.id).toSet()
          : {..._repostedPostIds, post.id};
    });
    try {
      await RepostService.toggleRepost(post.id, currentlyReposted: wasReposted);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasReposted ? 'Repost removed' : 'Reposted')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _repostedPostIds = wasReposted
            ? {..._repostedPostIds, post.id}
            : _repostedPostIds.where((id) => id != post.id).toSet();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to repost right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StoriesTray(refreshToken: widget.refreshToken + _storiesRefresh),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: widget.borderlessComposer
              ? const BoxDecoration(color: Colors.transparent)
              : BoxDecoration(
                  color: fv.elevatedSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: fv.borderSubtle),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProfileAvatarThumbnail(
                    imageUrl: _avatarUrl,
                    displayName: _displayName,
                    radius: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: fv.surface,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: _openCreatePost,
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Text(
                            "What's on your mind, $_displayName?",
                            style: TextStyle(
                              color: fv.tertiaryText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: fv.divider),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ComposerAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Photo',
                    color: FirstVueColors.teal,
                    onTap: _openCreatePost,
                  ),
                  _ComposerAction(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: FirstVueColors.coral,
                    onTap: _openCreatePost,
                  ),
                  _ComposerAction(
                    icon: Icons.auto_awesome_motion_outlined,
                    label: 'Story',
                    color: FirstVueColors.gold,
                    onTap: _openStoryComposer,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (widget.showTitle)
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: FirstVueColors.teal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MAIN NEWSFEED',
                style: TextStyle(
                  color: fv.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading
                    ? null
                    : () => _loadFeed(reshuffle: true),
                icon: Icon(Icons.refresh, color: fv.mutedIcon, size: 20),
                tooltip: 'Refresh feed',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        if (widget.showTitle) const SizedBox(height: 8),
        if (_loading && _posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_error != null && _posts.isEmpty)
          _EmptyFeedState(
            title: _error!,
            actionLabel: 'Try again',
            onAction: () => _loadFeed(reshuffle: true),
          )
        else if (_posts.isEmpty)
          const _EmptyFeedState(
            title: 'No community posts yet',
            subtitle: 'Be the first to share something with your community.',
          )
        else
          Column(
            children: [
              for (var index = 0; index < _posts.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                FeedImpressionTracker(
                  postId: _posts[index].id,
                  feedSource: 'main',
                  child: CommunityNewsPostCard(
                    post: _posts[index],
                    style: CommunityNewsPostCardStyle.timeline,
                    onTap: () => CommunityNewsPostDetailSheet.show(
                      context,
                      postId: _posts[index].id,
                      initialPost: _posts[index],
                    ),
                    onAuthorTap: _posts[index].authorId.isNotEmpty
                        ? () => openMemberProfile(
                            context,
                            profileId: _posts[index].authorId,
                            displayName: _posts[index].authorName,
                          )
                        : null,
                    onSpark: () => _sparkPost(index),
                    onSave: () => _savePost(index),
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: _posts[index].commentsMediaId,
                      businessName: _posts[index].authorName,
                    ),
                    onRepost: () => _repostPost(index),
                    onShare: () {
                      final post = _posts[index];
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
                        sourceTab: 'main',
                      );
                    },
                    repostedByMe: _repostedPostIds.contains(_posts[index].id),
                  ),
                ),
              ],
              if (_hasMore && _posts.length >= 8) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? 'Loading…' : 'See more posts'),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: FirstVueColors.ivory.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      decoration: BoxDecoration(
        color: FirstVueColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FirstVueColors.ivory.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.newspaper_outlined,
            size: 28,
            color: FirstVueColors.mutedIcon,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FirstVueColors.ivory,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FirstVueColors.ivory.withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
