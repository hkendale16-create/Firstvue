import 'package:flutter/material.dart';

import '../services/hashtag_service.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../services/web_seo_service.dart';

class HashtagPostsScreen extends StatefulWidget {
  final String tag;

  const HashtagPostsScreen({super.key, required this.tag});

  @override
  State<HashtagPostsScreen> createState() => _HashtagPostsScreenState();
}

class _HashtagPostsScreenState extends State<HashtagPostsScreen> {
  late Future<List<CommunityNewsPost>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = HashtagService.fetchPostsByTag(widget.tag);
    WebSeoService.update(
      title: '#${widget.tag} · FirstVue',
      description: 'Community posts tagged #${widget.tag} on FirstVue.',
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _postsFuture = HashtagService.fetchPostsByTag(widget.tag);
    });
    await _postsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('#${widget.tag}'),
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: FutureBuilder<List<CommunityNewsPost>>(
          future: _postsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: FirstVueColors.teal),
              );
            }
            final posts = snapshot.data ?? const [];
            if (posts.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'No posts with #${widget.tag} yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.fv.secondaryText),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final post = posts[index];
                return CommunityNewsPostCard(
                  post: post,
                  style: CommunityNewsPostCardStyle.timeline,
                  onTap: () => CommunityNewsPostDetailSheet.show(
                    context,
                    postId: post.id,
                    initialPost: post,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
