import '../services/community_news_service.dart';
import '../services/repost_service.dart';

/// Shared feed scopes for Home + every profile/entity surface.
///
/// Community and Group both filter `community_news_posts.community_id`
/// because FirstVue stores Groups in `public.communities` (no `group_id`).
enum FirstVueFeedScope {
  home,
  personal,
  business,
  professional,
  event,
  community,
  group,
}

class FirstVueFeedPage {
  final List<CommunityNewsPost> posts;
  final Set<String> repostedPostIds;
  final bool hasMore;
  final Object? error;
  final String? errorDetail;

  const FirstVueFeedPage({
    required this.posts,
    this.repostedPostIds = const {},
    this.hasMore = false,
    this.error,
    this.errorDetail,
  });

  bool get isError => error != null;
}

/// Single shared feed query engine against `public.community_news_posts`.
///
/// Does not create a new posts table. Permissions stay in Supabase RLS.
class FirstVueFeedService {
  FirstVueFeedService._();

  static const defaultPageSize = 20;

  static Future<FirstVueFeedPage> fetchPage({
    required FirstVueFeedScope scope,
    String? entityId,
    String? authorId,
    int limit = defaultPageSize,
    DateTime? beforeCreatedAt,
  }) async {
    try {
      final posts = await _fetchScoped(
        scope: scope,
        entityId: entityId,
        authorId: authorId,
        limit: limit + 1,
        beforeCreatedAt: beforeCreatedAt,
      );

      final hasMore = posts.length > limit;
      final pagePosts = hasMore ? posts.take(limit).toList() : posts;
      final deduped = _dedupeById(pagePosts);

      Set<String> reposted = const {};
      Map<String, int> repostCounts = const {};
      try {
        final ids = deduped.map((p) => p.id).toList();
        reposted = await RepostService.fetchMyRepostedIds(ids);
        repostCounts = await RepostService.fetchRepostCounts(ids);
      } catch (error) {
        CommunityNewsService.logFeedError(
          error,
          context: 'FirstVueFeed.repostMeta',
        );
      }

      final withReposts = [
        for (final post in deduped)
          post.copyWith(repostCount: repostCounts[post.id] ?? post.repostCount),
      ];

      return FirstVueFeedPage(
        posts: withReposts,
        repostedPostIds: reposted,
        hasMore: hasMore,
      );
    } catch (error) {
      CommunityNewsService.logFeedError(
        error,
        context: 'FirstVueFeed.${scope.name}',
      );
      return FirstVueFeedPage(
        posts: const [],
        error: error,
        errorDetail: CommunityNewsService.describeFeedError(error),
      );
    }
  }

  static Future<List<CommunityNewsPost>> _fetchScoped({
    required FirstVueFeedScope scope,
    String? entityId,
    String? authorId,
    required int limit,
    DateTime? beforeCreatedAt,
  }) async {
    switch (scope) {
      case FirstVueFeedScope.home:
        // Broad News Feed — do NOT require community_id / group_id.
        return CommunityNewsService.fetchPosts(
          limit: limit,
          beforeCreatedAt: beforeCreatedAt,
        );
      case FirstVueFeedScope.personal:
        if (authorId != null && authorId.isNotEmpty) {
          return CommunityNewsService.fetchPostsByAuthor(
            authorId,
            limit: limit,
            beforeCreatedAt: beforeCreatedAt,
          );
        }
        return CommunityNewsService.fetchMyPosts(
          limit: limit,
          beforeCreatedAt: beforeCreatedAt,
        );
      case FirstVueFeedScope.business:
        if (entityId == null || entityId.isEmpty) return const [];
        return CommunityNewsService.fetchPostsForBusiness(
          entityId,
          limit: limit,
          beforeCreatedAt: beforeCreatedAt,
        );
      case FirstVueFeedScope.professional:
        if (entityId == null || entityId.isEmpty) return const [];
        return CommunityNewsService.fetchPostsForProfessional(
          entityId,
          limit: limit,
          beforeCreatedAt: beforeCreatedAt,
        );
      case FirstVueFeedScope.event:
        if (entityId == null || entityId.isEmpty) return const [];
        return CommunityNewsService.fetchPostsForEvent(
          entityId,
          limit: limit,
          beforeCreatedAt: beforeCreatedAt,
        );
      case FirstVueFeedScope.community:
      case FirstVueFeedScope.group:
        if (entityId == null || entityId.isEmpty) return const [];
        return CommunityNewsService.fetchPostsForCommunity(
          entityId,
          limit: limit,
          beforeCreatedAt: beforeCreatedAt,
        );
    }
  }

  static List<CommunityNewsPost> _dedupeById(List<CommunityNewsPost> posts) {
    final seen = <String>{};
    final out = <CommunityNewsPost>[];
    for (final post in posts) {
      if (seen.add(post.id)) out.add(post);
    }
    return out;
  }
}
