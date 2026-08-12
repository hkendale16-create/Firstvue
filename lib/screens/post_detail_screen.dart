import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../services/web_seo_service.dart';
import '../widgets/firstvue_share_sheet.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final CommunityNewsPost? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
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
      if (post != null) {
        WebSeoService.update(
          title: '${post.authorName} on FirstVue',
          description: post.body.length > 160
              ? '${post.body.substring(0, 160)}…'
              : post.body,
          canonicalUrl: AppConfig.newsPostShareUrl(post.id),
        );
      }
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
      if (mounted) setState(() => _post = updated);
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
    }
  }

  Future<void> _toggleSave() async {
    final post = _post;
    if (post == null) return;
    final previous = post;
    setState(() => _post = post.copyWith(savedByMe: !post.savedByMe));
    try {
      final updated = await CommunityNewsService.toggleSave(post);
      if (mounted) setState(() => _post = updated);
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
    }
  }

  Future<void> _deletePost() async {
    final post = _post;
    if (post == null) return;
    final deleted = await confirmDeleteNewsPost(context, post);
    if (deleted && mounted) Navigator.pop(context);
  }

  void _share() {
    final post = _post;
    if (post == null) return;
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: 'Post by ${post.authorName}',
        subtitle: post.body,
        link: AppConfig.newsPostShareUrl(post.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('POST'),
        actions: [
          IconButton(
            onPressed: _post == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FirstVueColors.teal))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.white54)),
                      TextButton(onPressed: _loadPost, child: const Text('Try again')),
                    ],
                  ),
                )
              : FirstVueRefreshScaffold(
                  onRefresh: _loadPost,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_post != null)
                        CommunityNewsPostCard(
                          post: _post!,
                          style: CommunityNewsPostCardStyle.timeline,
                          onAuthorTap: _post!.authorId.isNotEmpty
                              ? () => openMemberProfile(
                                    context,
                                    profileId: _post!.authorId,
                                    displayName: _post!.authorName,
                                  )
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
                    ],
                  ),
                ),
    );
  }
}
