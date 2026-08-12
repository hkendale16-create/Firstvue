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
  late Future<List<CommunityNewsPost>> _postsFuture;
  final _composer = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _postsFuture = CommunityNewsService.fetchPosts();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _postsFuture = CommunityNewsService.fetchPosts());
    await _postsFuture;
  }

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
      await CommunityNewsService.createPost(text);
      _composer.clear();
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

  Future<void> _sparkPost(CommunityNewsPost post) async {
    try {
      await CommunityNewsService.toggleSpark(post);
      if (!mounted) return;
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
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
        FutureBuilder<List<CommunityNewsPost>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: FirstVueColors.teal),
                ),
              );
            }
            final posts = snapshot.data!;
            if (posts.isEmpty) {
              return const Text(
                'Community posts will appear here.',
                style: TextStyle(color: Colors.white54),
              );
            }
            return Column(
              children: posts.map((post) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NewsPostCard(
                    post: post,
                    onSpark: () => _sparkPost(post),
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: post.commentsMediaId,
                      businessName: post.authorName,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _NewsPostCard extends StatelessWidget {
  final CommunityNewsPost post;
  final VoidCallback onSpark;
  final VoidCallback onComment;

  const _NewsPostCard({
    required this.post,
    required this.onSpark,
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
                icon: Icon(
                  post.sparkedByMe ? Icons.bolt_rounded : Icons.bolt_outlined,
                  size: 18,
                ),
                label: Text('${post.sparkCount} sparks'),
              ),
              TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Comment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
