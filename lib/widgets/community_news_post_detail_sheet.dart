import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../services/community_news_service.dart';
import 'community_news_post_card.dart';
import 'feed_comments_sheet.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10151B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: CommunityNewsPostDetailSheet(
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
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
                          onSpark: _toggleSpark,
                          onSave: _toggleSave,
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
