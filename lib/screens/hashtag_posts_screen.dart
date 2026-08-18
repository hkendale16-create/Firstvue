import 'package:flutter/material.dart';

import '../services/hashtag_service.dart';
import '../services/community_news_service.dart';
import '../services/story_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../services/web_seo_service.dart';
import 'story_viewer_screen.dart';

class HashtagPostsScreen extends StatefulWidget {
  final String tag;

  const HashtagPostsScreen({super.key, required this.tag});

  @override
  State<HashtagPostsScreen> createState() => _HashtagPostsScreenState();
}

class _HashtagPostsScreenState extends State<HashtagPostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Future<List<CommunityNewsPost>> _postsFuture;
  late Future<List<CommunityNewsPost>> _vueFuture;
  late Future<List<StoryItem>> _storiesFuture;
  late Future<List<TrendingHashtag>> _localFuture;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _postsFuture = HashtagService.fetchPostsByTag(widget.tag);
    _vueFuture = HashtagService.fetchPostsByTag(widget.tag, vueOnly: true);
    _storiesFuture = HashtagService.fetchStoriesByTag(widget.tag);
    _localFuture = HashtagService.fetchTrending(limit: 12, nearYou: true);
    WebSeoService.update(
      title: '#${widget.tag} · FirstVue',
      description: 'Public FirstVue content tagged #${widget.tag}.',
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _postsFuture = HashtagService.fetchPostsByTag(widget.tag);
      _vueFuture = HashtagService.fetchPostsByTag(widget.tag, vueOnly: true);
      _storiesFuture = HashtagService.fetchStoriesByTag(widget.tag);
      _localFuture = HashtagService.fetchTrending(limit: 12, nearYou: true);
    });
    await Future.wait([
      _postsFuture,
      _vueFuture,
      _storiesFuture,
      _localFuture,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('#${widget.tag}'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: FirstVueColors.teal,
          unselectedLabelColor: fv.secondaryText,
          indicatorColor: FirstVueColors.teal,
          tabs: const [
            Tab(text: 'Top'),
            Tab(text: 'Recent'),
            Tab(text: 'VUE'),
            Tab(text: 'Stories'),
            Tab(text: 'Near you'),
          ],
        ),
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabs,
          children: [
            _PostsTab(
              future: _postsFuture.then(HashtagQuery.sortTop),
              emptyLabel: 'No public posts with #${widget.tag} yet.',
            ),
            _PostsTab(
              future: _postsFuture,
              emptyLabel: 'No recent posts with #${widget.tag} yet.',
            ),
            _PostsTab(
              future: _vueFuture,
              emptyLabel: 'No VUE posts with #${widget.tag} yet.',
            ),
            _StoriesTab(future: _storiesFuture, tag: widget.tag),
            _RelatedTab(
              future: _localFuture,
              currentTag: widget.tag,
              emptyLabel: 'No local hashtag trends yet.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  final Future<List<CommunityNewsPost>> future;
  final String emptyLabel;

  const _PostsTab({
    required this.future,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityNewsPost>>(
      future: future,
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
                emptyLabel,
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
    );
  }
}

class _StoriesTab extends StatelessWidget {
  final Future<List<StoryItem>> future;
  final String tag;

  const _StoriesTab({required this.future, required this.tag});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StoryItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: FirstVueColors.teal),
          );
        }
        final stories = snapshot.data ?? const [];
        if (stories.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              Text(
                'No active Stories with #$tag.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.fv.secondaryText),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stories.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final story = stories[index];
            return ListTile(
              tileColor: context.fv.elevatedSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                story.ownerName,
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                story.caption ?? 'Active Story',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.fv.secondaryText),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final rings = await StoryService.fetchActiveRings();
                if (!context.mounted) return;
                final ringIndex = rings.indexWhere(
                  (ring) => ring.stories.any((s) => s.id == story.id),
                );
                if (ringIndex < 0) return;
                await StoryViewerScreen.open(
                  context,
                  rings: rings,
                  initialRingIndex: ringIndex,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RelatedTab extends StatelessWidget {
  final Future<List<TrendingHashtag>> future;
  final String currentTag;
  final String emptyLabel;

  const _RelatedTab({
    required this.future,
    required this.currentTag,
    this.emptyLabel = 'Trending hashtags will appear here.',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrendingHashtag>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: FirstVueColors.teal),
          );
        }
        final tags = (snapshot.data ?? const [])
            .where((t) => t.tag.toLowerCase() != currentTag.toLowerCase())
            .toList();
        if (tags.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.fv.secondaryText),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tags.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = tags[index];
            return ListTile(
              leading: const Icon(Icons.tag_rounded, color: FirstVueColors.gold),
              title: Text(
                '#${item.tag}',
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                item.recentUses > 0
                    ? '${item.recentUses} recent · ${item.uniqueActors} people'
                    : '${item.useCount} uses',
                style: TextStyle(color: context.fv.tertiaryText, fontSize: 12),
              ),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HashtagPostsScreen(tag: item.tag),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
