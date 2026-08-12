import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/firstvue_feed_service.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/professional_public_profile_screen.dart';
import '../services/community_news_service.dart';
import '../services/interaction_preferences_service.dart';
import '../services/professional_profiles_service.dart';
import '../services/repost_service.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/app_environment.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/event_profile_sheet.dart';
import '../widgets/feed_comments_sheet.dart';

/// Borderless shared feed renderer for Home + all entity profiles.
class FirstVueFeed extends StatefulWidget {
  final FirstVueFeedScope scope;
  final String? entityId;
  final String? authorId;
  final int refreshToken;
  final bool showTitle;
  final String title;
  final String emptyMessage;
  final bool enableRealtime;
  final bool enablePagination;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  const FirstVueFeed({
    super.key,
    required this.scope,
    this.entityId,
    this.authorId,
    this.refreshToken = 0,
    this.showTitle = true,
    this.title = 'NEWS FEED',
    this.emptyMessage = 'No posts yet',
    this.enableRealtime = false,
    this.enablePagination = true,
    this.header,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<FirstVueFeed> createState() => FirstVueFeedState();
}

class FirstVueFeedState extends State<FirstVueFeed> {
  final List<CommunityNewsPost> _posts = [];
  Set<String> _repostedPostIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _errorDetail;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.enableRealtime) _subscribeRealtime();
  }

  @override
  void didUpdateWidget(covariant FirstVueFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.scope != widget.scope ||
        oldWidget.entityId != widget.entityId ||
        oldWidget.authorId != widget.authorId) {
      _reload();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> refresh() => _reload();

  void prependPost(CommunityNewsPost post) {
    setState(() {
      _posts.removeWhere((p) => p.id == post.id);
      _posts.insert(0, post);
      _loading = false;
      _errorDetail = null;
    });
  }

  void _subscribeRealtime() {
    if (isWidgetTestBinding) return;
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('firstvue-feed-${widget.scope.name}')
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
            if (_posts.any((p) => p.id == postId)) return;
            if (!_matchesScope(record)) return;
            final post = await CommunityNewsService.fetchPostById(postId);
            if (post == null || !mounted) return;
            prependPost(post);
          },
        )
        .subscribe();
  }

  bool _matchesScope(Map<String, dynamic> record) {
    switch (widget.scope) {
      case FirstVueFeedScope.home:
        return true;
      case FirstVueFeedScope.personal:
        final author = widget.authorId ??
            Supabase.instance.client.auth.currentUser?.id;
        return author != null && record['author_id'] == author;
      case FirstVueFeedScope.business:
        return widget.entityId != null &&
            record['business_id'] == widget.entityId;
      case FirstVueFeedScope.professional:
        return widget.entityId != null &&
            record['professional_profile_id'] == widget.entityId;
      case FirstVueFeedScope.event:
        return widget.entityId != null && record['event_id'] == widget.entityId;
      case FirstVueFeedScope.community:
      case FirstVueFeedScope.group:
        return widget.entityId != null &&
            record['community_id'] == widget.entityId;
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _errorDetail = null;
    });
    final page = await FirstVueFeedService.fetchPage(
      scope: widget.scope,
      entityId: widget.entityId,
      authorId: widget.authorId,
    );
    if (!mounted) return;
    setState(() {
      _posts
        ..clear()
        ..addAll(page.posts);
      _repostedPostIds = page.repostedPostIds;
      _hasMore = page.hasMore;
      _loading = false;
      _errorDetail = page.isError ? page.errorDetail : null;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    final page = await FirstVueFeedService.fetchPage(
      scope: widget.scope,
      entityId: widget.entityId,
      authorId: widget.authorId,
      beforeCreatedAt: _posts.last.createdAt,
    );
    if (!mounted) return;
    setState(() {
      final existing = _posts.map((p) => p.id).toSet();
      for (final post in page.posts) {
        if (existing.add(post.id)) _posts.add(post);
      }
      _repostedPostIds = {..._repostedPostIds, ...page.repostedPostIds};
      _hasMore = page.hasMore;
      _loadingMore = false;
      if (page.isError && _posts.isEmpty) {
        _errorDetail = page.errorDetail;
      }
    });
  }

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final previous = _posts[index];
    setState(() {
      _posts[index] = previous.copyWith(
        sparkedByMe: !previous.sparkedByMe,
        sparkCount: previous.sparkedByMe
            ? (previous.sparkCount - 1).clamp(0, 1 << 30)
            : previous.sparkCount + 1,
      );
    });
    try {
      final updated = await CommunityNewsService.toggleSpark(previous);
      if (!mounted) return;
      setState(() => _posts[index] = updated);
      if (updated.sparkedByMe) {
        InteractionPreferencesService.playSparkFeedback(fromUserTap: true);
      }
    } on AuthException {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (error) {
      CommunityNewsService.logFeedError(error, context: 'FirstVueFeed.spark');
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _savePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final previous = _posts[index];
    setState(() {
      _posts[index] = previous.copyWith(savedByMe: !previous.savedByMe);
    });
    try {
      final updated = await CommunityNewsService.toggleSave(previous);
      if (!mounted) return;
      setState(() => _posts[index] = updated);
    } on AuthException {
      if (!mounted) return;
      setState(() => _posts[index] = previous);
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (error) {
      CommunityNewsService.logFeedError(error, context: 'FirstVueFeed.save');
      if (!mounted) return;
      setState(() => _posts[index] = previous);
    }
  }

  Future<void> _repostPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasReposted = _repostedPostIds.contains(post.id);
    setState(() {
      if (wasReposted) {
        _repostedPostIds = {..._repostedPostIds}..remove(post.id);
        _posts[index] = post.copyWith(
          repostCount: (post.repostCount - 1).clamp(0, 1 << 30),
        );
      } else {
        _repostedPostIds = {..._repostedPostIds, post.id};
        _posts[index] = post.copyWith(repostCount: post.repostCount + 1);
      }
    });
    try {
      if (wasReposted) {
        await RepostService.undoRepost(post.id);
      } else {
        await RepostService.repost(post.id);
      }
    } on AuthException {
      if (!mounted) return;
      setState(() {
        if (wasReposted) {
          _repostedPostIds = {..._repostedPostIds, post.id};
        } else {
          _repostedPostIds = {..._repostedPostIds}..remove(post.id);
        }
        _posts[index] = post;
      });
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (error) {
      CommunityNewsService.logFeedError(error, context: 'FirstVueFeed.repost');
      if (!mounted) return;
      setState(() {
        if (wasReposted) {
          _repostedPostIds = {..._repostedPostIds, post.id};
        } else {
          _repostedPostIds = {..._repostedPostIds}..remove(post.id);
        }
        _posts[index] = post;
      });
    }
  }

  Future<void> _deletePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final deleted = await confirmDeleteNewsPost(context, _posts[index]);
    if (!deleted || !mounted) return;
    setState(() => _posts.removeAt(index));
  }

  Future<void> _openCreator(CommunityNewsPost post) async {
    switch (post.entityKind) {
      case FeedEntityKind.business:
        final id = post.businessId;
        if (id == null) return;
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => FirstVueBusinessProfileScreen(businessId: id),
          ),
        );
      case FeedEntityKind.professional:
        final id = post.professionalProfileId;
        if (id == null) return;
        final profile = await ProfessionalProfilesService.fetchById(id);
        if (!mounted || profile == null) return;
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => ProfessionalPublicProfileScreen(
              profile: profile,
              icon: Icons.badge_outlined,
            ),
          ),
        );
      case FeedEntityKind.event:
        final id = post.eventId;
        if (id == null) return;
        final events = await ThingsToDoService.fetchApprovedEvents();
        CommunityEvent? event;
        for (final item in events) {
          if (item.id == id) {
            event = item;
            break;
          }
        }
        if (!mounted || event == null) return;
        await EventProfileSheet.show(context, event: event);
      case FeedEntityKind.community:
      case FeedEntityKind.group:
        final id = post.communityId;
        if (id == null) return;
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityDetailScreen(communityId: id),
          ),
        );
      case FeedEntityKind.personal:
        if (post.authorId.isEmpty) return;
        openMemberProfile(
          context,
          profileId: post.authorId,
          displayName: post.authorName,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle)
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: FirstVueColors.ivory,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                if (!_loading)
                  IconButton(
                    onPressed: refresh,
                    icon: const Icon(
                      Icons.refresh,
                      color: FirstVueColors.mutedIcon,
                      size: 20,
                    ),
                    tooltip: 'Refresh feed',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          if (widget.header != null) ...[
            const SizedBox(height: 12),
            widget.header!,
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(color: FirstVueColors.teal),
              ),
            )
          else if (_errorDetail != null && _posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errorDetail!,
                    style: TextStyle(color: Colors.white.withValues(alpha: .54)),
                  ),
                  TextButton(onPressed: refresh, child: const Text('Try again')),
                ],
              ),
            )
          else if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                widget.emptyMessage,
                style: TextStyle(color: Colors.white.withValues(alpha: .5)),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < _posts.length; index++) ...[
                  CommunityNewsPostCard(
                    post: _posts[index],
                    style: CommunityNewsPostCardStyle.timeline,
                    onTap: () => CommunityNewsPostDetailSheet.show(
                      context,
                      postId: _posts[index].id,
                      initialPost: _posts[index],
                    ),
                    onAuthorTap: () => _openCreator(_posts[index]),
                    onSpark: () => _sparkPost(index),
                    onSave: () => _savePost(index),
                    onRepost: () => _repostPost(index),
                    repostedByMe:
                        _repostedPostIds.contains(_posts[index].id),
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: _posts[index].commentsMediaId,
                      businessName: _posts[index].authorName,
                    ),
                    onDelete: _posts[index].isMine
                        ? () => _deletePost(index)
                        : null,
                  ),
                  if (_posts[index].communityName != null &&
                      (_posts[index].communityId ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _openCreator(_posts[index]),
                        child: Text(
                          _posts[index].viewActionLabel == 'View Group' ||
                                  _posts[index].viewActionLabel ==
                                      'View Community'
                              ? '${_posts[index].viewActionLabel}: ${_posts[index].communityName}'
                              : _posts[index].viewActionLabel,
                          style: const TextStyle(
                            color: FirstVueColors.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
                if (widget.enablePagination && _hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore ? 'Loading…' : 'Load more'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
