import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/feed_comments_sheet.dart';
import '../screens/auth_screen.dart';

class HomeNewsFeedSection extends StatefulWidget {
  const HomeNewsFeedSection({super.key});

  @override
  State<HomeNewsFeedSection> createState() => _HomeNewsFeedSectionState();
}

class _HomeNewsFeedSectionState extends State<HomeNewsFeedSection> {
  List<CommunityNewsPost> _posts = const [];
  bool _loadingPosts = true;
  final _composer = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final posts = await CommunityNewsService.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loadingPosts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _refresh() => _loadPosts();

  Future<void> _submitPost() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }
    final text = _composer.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final newPost = await CommunityNewsService.createPost(text);
      _composer.clear();
      if (!mounted) return;
      setState(() {
        _posts = [
          newPost,
          for (final post in _posts)
            if (post.id != newPost.id) post,
        ];
        _loadingPosts = false;
      });
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to post right now.')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
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
        MaterialPageRoute(builder: (_) => const AuthScreen()),
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
        MaterialPageRoute(builder: (_) => const AuthScreen()),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEWS FEED',
          style: TextStyle(
            color: FirstVueColors.ivory,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FirstVueColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FirstVueColors.gold.withValues(alpha: .35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'POST HERE',
                    style: TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _composer,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share news, updates, or shoutouts with the community...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: .38)),
                      filled: true,
                      fillColor: FirstVueColors.elevatedSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _posting ? null : _submitPost,
                      style: FilledButton.styleFrom(
                        backgroundColor: FirstVueColors.coral,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_posting ? 'POSTING...' : 'POST'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingPosts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_posts.isEmpty)
          const Text(
            'Community posts will appear here.',
            style: TextStyle(color: Colors.white54),
          )
        else
          Column(
            children: [
              for (var index = 0; index < _posts.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NewsPostCard(
                    post: _posts[index],
                    onSpark: () => _sparkPost(index),
                    onSave: () => _savePost(index),
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: _posts[index].commentsMediaId,
                      businessName: _posts[index].authorName,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _NewsPostCard extends StatelessWidget {
  final CommunityNewsPost post;
  final VoidCallback onSpark;
  final VoidCallback onSave;
  final VoidCallback onComment;

  const _NewsPostCard({
    required this.post,
    required this.onSpark,
    required this.onSave,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.authorName,
                  style: const TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (post.businessName != null)
                Text(
                  post.businessName!,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: onSpark,
                style: TextButton.styleFrom(
                  foregroundColor:
                      post.sparkedByMe ? FirstVueColors.gold : Colors.white70,
                ),
                icon: Icon(
                  post.sparkedByMe ? Icons.bolt_rounded : Icons.bolt_outlined,
                  size: 18,
                  color: post.sparkedByMe ? FirstVueColors.gold : Colors.white70,
                ),
                label: Text('${post.sparkCount} sparks'),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Comment'),
              ),
              TextButton.icon(
                onPressed: onSave,
                style: TextButton.styleFrom(
                  foregroundColor:
                      post.savedByMe ? FirstVueColors.gold : Colors.white70,
                ),
                icon: Icon(
                  post.savedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border,
                  size: 18,
                  color: post.savedByMe ? FirstVueColors.gold : Colors.white70,
                ),
                label: Text(post.savedByMe ? 'Saved' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
