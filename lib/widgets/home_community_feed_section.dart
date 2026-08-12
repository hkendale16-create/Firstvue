import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';

/// Homepage preview of posts from communities the user joined or follows.
///
/// Separate from [HomeNewsFeedSection] (the broad FirstVue News Feed).
class HomeCommunityFeedSection extends StatefulWidget {
  final int refreshToken;

  const HomeCommunityFeedSection({super.key, this.refreshToken = 0});

  @override
  State<HomeCommunityFeedSection> createState() =>
      _HomeCommunityFeedSectionState();
}

class _HomeCommunityFeedSectionState extends State<HomeCommunityFeedSection> {
  List<CommunityNewsPost> _posts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeCommunityFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final posts = await CommunityNewsService.fetchCommunityFeed(limit: 8);
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'COMMUNITY FEED',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => const CommunitiesScreen(),
                  ),
                );
              },
              child: const Text('See groups'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const SizedBox(
            height: 72,
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_posts.isEmpty)
          const Text(
            'Posts from groups you join or follow will appear here.',
            style: TextStyle(color: Colors.white54),
          )
        else
          Column(
            children: [
              for (final post in _posts.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CommunityNewsPostCard(
                    post: post,
                    style: CommunityNewsPostCardStyle.timeline,
                    onTap: () => CommunityNewsPostDetailSheet.show(
                      context,
                      postId: post.id,
                      initialPost: post,
                    ),
                    onAuthorTap: post.authorId.isNotEmpty
                        ? () => openMemberProfile(
                              context,
                              profileId: post.authorId,
                              displayName: post.authorName,
                            )
                        : null,
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: post.commentsMediaId,
                      businessName: post.authorName,
                    ),
                  ),
                ),
              if (_posts.any((p) => p.communityId != null))
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      final first = _posts.firstWhere(
                        (p) => p.communityId != null,
                      );
                      Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => CommunityDetailScreen(
                            communityId: first.communityId!,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open a group'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
