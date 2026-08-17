import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/share_payload.dart';
import '../config/app_config.dart';
import '../auth/ensure_signed_in.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'firstvue_share_sheet.dart';
import '../screens/boost_post_sheet.dart';
import '../screens/edit_post_screen.dart';

class ProfileMyPostsSection extends StatefulWidget {
  final int refreshToken;
  final bool embedded;

  const ProfileMyPostsSection({
    super.key,
    this.refreshToken = 0,
    this.embedded = false,
  });

  @override
  State<ProfileMyPostsSection> createState() => _ProfileMyPostsSectionState();
}

class _ProfileMyPostsSectionState extends State<ProfileMyPostsSection> {
  static const _pageSize = 12;

  final List<CommunityNewsPost> _posts = [];
  final Set<String> _seenIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ProfileMyPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final posts = await CommunityNewsService.fetchMyPosts(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _seenIds
          ..clear()
          ..addAll(posts.map((p) => p.id));
        _loading = false;
        _hasMore = posts.length >= _pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load your posts.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await CommunityNewsService.fetchMyPosts(
        limit: _pageSize,
        beforeCreatedAt: _posts.last.createdAt,
        beforeId: _posts.last.id,
      );
      final fresh = more.where((p) => _seenIds.add(p.id)).toList();
      if (!mounted) return;
      setState(() {
        _posts.addAll(fresh);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = 'Could not load more posts.';
      });
    }
  }

  Future<bool> _ensureSignedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return true;
    await ensureSignedIn(context);
    return Supabase.instance.client.auth.currentUser != null;
  }

  Future<void> _withBusy(String id, Future<void> Function() action) async {
    if (_busyIds.contains(id)) return;
    _busyIds.add(id);
    try {
      await action();
    } finally {
      _busyIds.remove(id);
    }
  }

  Future<void> _savePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    await _withBusy(_posts[index].id, () async {
      if (Supabase.instance.client.auth.currentUser == null) {
        if (!await _ensureSignedIn()) return;
        if (!mounted || index >= _posts.length) return;
      }
      final post = _posts[index];
      final previous = post;
      final optimistic = post.copyWith(savedByMe: !post.savedByMe);
      setState(() => _posts[index] = optimistic);
      try {
        final updated = await CommunityNewsService.toggleSave(post);
        if (!mounted) return;
        setState(() => _posts[index] = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.savedByMe
                  ? 'Saved to Favorites'
                  : 'Removed from Favorites',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } on AuthException {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        if (await _ensureSignedIn() && mounted) {
          await _savePost(index);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save this post right now.')),
        );
      }
    });
  }

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    await _withBusy(_posts[index].id, () async {
      if (Supabase.instance.client.auth.currentUser == null) {
        if (!await _ensureSignedIn()) return;
        if (!mounted || index >= _posts.length) return;
      }
      final post = _posts[index];
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
      } on AuthException {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        if (await _ensureSignedIn() && mounted) {
          await _sparkPost(index);
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _posts[index] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to spark this post right now.')),
        );
      }
    });
  }

  Future<void> _sharePost(CommunityNewsPost post) async {
    await FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: post.authorName,
        link: AppConfig.newsPostShareUrl(post.id),
        subtitle: post.body,
      ),
    );
  }

  Future<void> _deletePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final deleted = await confirmDeleteNewsPost(context, _posts[index]);
    if (!deleted || !mounted) return;
    final removed = _posts[index];
    setState(() {
      _posts.removeAt(index);
      _seenIds.remove(removed.id);
    });
  }

  Widget _buildPostList({required bool compact}) {
    return Column(
      children: [
        for (var index = 0; index < _posts.length; index++)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 10),
            child: CommunityNewsPostCard(
              post: _posts[index],
              compact: true,
              onTap: () => CommunityNewsPostDetailSheet.show(
                context,
                postId: _posts[index].id,
                initialPost: _posts[index],
              ),
              onSpark: () => _sparkPost(index),
              onSave: () => _savePost(index),
              onShare: () => _sharePost(_posts[index]),
              onComment: () => FeedCommentsSheet.show(
                context,
                mediaId: _posts[index].commentsMediaId,
                businessName: _posts[index].authorName,
              ),
              onDelete: _posts[index].isMine ? () => _deletePost(index) : null,
              onEdit: _posts[index].isMine
                  ? () async {
                      final updated = await EditPostScreen.open(
                        context,
                        post: _posts[index],
                      );
                      if (updated == null || !mounted) return;
                      setState(() => _posts[index] = updated);
                    }
                  : null,
              onBoost: _posts[index].isMine
                  ? () => openBoostPostFlow(context, _posts[index])
                  : null,
            ),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: _loadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more posts'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final embedded = widget.embedded;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        embedded ? 16 : 20,
        0,
        embedded ? 16 : 20,
        embedded ? 0 : 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'MY POSTS',
                      style: TextStyle(
                        color: fv.secondaryText,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    icon: Icon(Icons.refresh, size: 18, color: fv.mutedIcon),
                    tooltip: 'Refresh posts',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          if (_loading && _posts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FirstVueColors.gold,
                  ),
                ),
              ),
            )
          else if (_error != null && _posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
              child: Column(
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: fv.secondaryText, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
              child: Text(
                'No posts yet. Share updates from the home feed and they will show up here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fv.secondaryText,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
            )
          else
            _buildPostList(compact: embedded),
        ],
      ),
    );
  }
}
