import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/post_detail_screen.dart';
import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../services/community_news_service.dart';
import 'community_news_post_card.dart';
import 'feed_comments_sheet.dart';
import 'firstvue_share_sheet.dart';

class CommunityNewsPostDetailSheet extends StatefulWidget {
  final String postId;
  final CommunityNewsPost? initialPost;

  const CommunityNewsPostDetailSheet({
    super.key,
    required this.postId,
    this.initialPost,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    CommunityNewsPost? initialPost,
  }) {
    final normalizedId = CommunityNewsService.normalizePostId(postId);
    return Navigator.of(context).push(
      FirstVuePageRoute(
        builder: (_) => PostDetailScreen(
          postId: normalizedId,
          initialPost: initialPost,
        ),
      ),
    );
  }

  @override
  State<CommunityNewsPostDetailSheet> createState() =>
      _CommunityNewsPostDetailSheetState();
}

class _CommunityNewsPostDetailSheetState
    extends State<CommunityNewsPostDetailSheet> {
  CommunityNewsPost? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
      _loading = false;
    } else {
      _loadPost();
    }
  }

  Future<void> _loadPost() async {
    if (widget.initialPost != null && _post != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await CommunityNewsService.fetchPostById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loading = false;
        _error = post == null ? 'Post not found.' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load this post.';
      });
    }
  }

  Future<void> _toggleSpark() async {
    final post = _post;
    if (post == null) return;
    final previous = post;
    setState(() {
      _post = post.copyWith(
        sparkedByMe: !post.sparkedByMe,
        sparkCount: post.sparkCount + (post.sparkedByMe ? -1 : 1),
      );
    });
    try {
      final updated = await CommunityNewsService.toggleSpark(post);
      if (!mounted) return;
      setState(() => _post = updated);
    } on AuthException {
      if (!mounted) return;
      setState(() => _post = previous);
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to spark this post right now.')),
      );
    }
  }

  Future<void> _toggleSave() async {
    final post = _post;
    if (post == null) return;
    final previous = post;
    setState(() => _post = post.copyWith(savedByMe: !post.savedByMe));
    try {
      final updated = await CommunityNewsService.toggleSave(post);
      if (!mounted) return;
      setState(() => _post = updated);
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
      setState(() => _post = previous);
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _post = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this post right now.')),
      );
    }
  }

  Future<void> _sharePost() async {
    final post = _post;
    if (post == null) return;

    await FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: 'Post by ${post.authorName}',
        subtitle: post.body,
        link: AppConfig.newsPostShareUrl(post.id),
      ),
    );
  }

  Future<void> _deletePost() async {
    final post = _post;
    if (post == null) return;
    final deleted = await confirmDeleteNewsPost(context, post);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'NEWS POST',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _post == null ? null : _sharePost,
                  icon: const Icon(Icons.route_outlined, color: Colors.white54),
                  tooltip: 'Route & share',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
                if (_post?.isMine == true)
                  IconButton(
                    onPressed: _deletePost,
                    icon: const Icon(Icons.delete_outline, color: Colors.white38),
                    tooltip: 'Delete post',
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD8B56A)),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              TextButton(
                                onPressed: _loadPost,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: CommunityNewsPostCard(
                          post: _post!,
                          onAuthorTap: _post!.authorId.isNotEmpty
                              ? () {
                                  Navigator.pop(context);
                                  openMemberProfile(
                                    context,
                                    profileId: _post!.authorId,
                                    displayName: _post!.authorName,
                                  );
                                }
                              : null,
                          onSpark: _toggleSpark,
                          onSave: _toggleSave,
                          onDelete: _post!.isMine ? _deletePost : null,
                          onComment: () => FeedCommentsSheet.show(
                            context,
                            mediaId: _post!.commentsMediaId,
                            businessName: _post!.authorName,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
