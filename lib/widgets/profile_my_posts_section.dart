import 'package:flutter/material.dart';
import '../theme/firstvue_theme.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth_screen.dart';
import '../services/community_news_service.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';

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
  late Future<List<CommunityNewsPost>> _postsFuture;
  List<CommunityNewsPost> _posts = const [];

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  @override
  void didUpdateWidget(covariant ProfileMyPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _postsFuture = _loadPosts();
    }
  }

  Future<List<CommunityNewsPost>> _loadPosts() async {
    final posts = await CommunityNewsService.fetchMyPosts();
    if (mounted) setState(() => _posts = posts);
    return posts;
  }

  Future<void> _refresh() async {
    setState(() => _postsFuture = _loadPosts());
    await _postsFuture;
  }

  Future<void> _savePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
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
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this post right now.')),
      );
    }
  }

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final previous = post;
    final optimistic = post.copyWith(
      sparkedByMe: !post.sparkedByMe,
      sparkCount: post.sparkCount + (post.sparkedByMe ? -1 : 1),
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
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to spark this post right now.')),
      );
    }
  }

  Future<void> _deletePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final deleted = await confirmDeleteNewsPost(context, _posts[index]);
    if (!deleted || !mounted) return;
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i != index) _posts[i],
      ];
    });
  }

  Future<void> _showPostMenu(int index) async {
    await _deletePost(index);
  }

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embedded;
    return Padding(
      padding: EdgeInsets.fromLTRB(embedded ? 16 : 20, 0, embedded ? 16 : 20, embedded ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!embedded)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MY POSTS',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.white38),
                    tooltip: 'Refresh posts',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          FutureBuilder<List<CommunityNewsPost>>(
            future: _postsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _posts.isEmpty) {
                return _PostsContainer(
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD8B56A),
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _PostsContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 22,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white.withValues(alpha: .35),
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unable to load your posts.',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final posts = snapshot.data ?? _posts;
              if (posts.isEmpty) {
                return embedded
                    ? _emptyState(
                        icon: Icons.campaign_outlined,
                        message:
                            'No posts yet. Share updates from the home feed and they will show up here.',
                      )
                    : _PostsContainer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 22,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.campaign_outlined,
                                color: Colors.white.withValues(alpha: .35),
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Text(
                                  'No posts yet. Share updates from the home news feed and they will appear here.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    height: 1.4,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
              }

              return Column(
                children: [
                  for (var index = 0; index < posts.length; index++)
                    Padding(
                      padding: EdgeInsets.only(bottom: embedded ? 0 : 10),
                      child: CommunityNewsPostCard(
                        post: posts[index],
                        compact: !embedded,
                        style: embedded
                            ? CommunityNewsPostCardStyle.timeline
                            : CommunityNewsPostCardStyle.compact,
                        onTap: () => CommunityNewsPostDetailSheet.show(
                          context,
                          postId: posts[index].id,
                          initialPost: posts[index],
                        ),
                        onSpark: () => _sparkPost(index),
                        onSave: () => _savePost(index),
                        onComment: () => FeedCommentsSheet.show(
                          context,
                          mediaId: posts[index].commentsMediaId,
                          businessName: posts[index].authorName,
                        ),
                        onDelete: posts[index].isMine
                            ? () => _showPostMenu(index)
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PostsContainer extends StatelessWidget {
  final Widget child;

  const _PostsContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: child,
    );
  }
}

Widget _emptyState({required IconData icon, required String message}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
    child: Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: .25), size: 40),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, height: 1.45, fontSize: 13),
        ),
      ],
    ),
  );
}
