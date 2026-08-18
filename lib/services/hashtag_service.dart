import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_news_service.dart';
import 'story_service.dart';
import 'user_preferences_service.dart';

class TrendingHashtag {
  final String tag;
  final double score;
  final int uniqueActors;
  final int recentUses;
  final int useCount;

  const TrendingHashtag({
    required this.tag,
    required this.score,
    required this.uniqueActors,
    required this.recentUses,
    required this.useCount,
  });
}

class HashtagQuery {
  HashtagQuery._();

  /// Tokenize a search string into indexed hashtag prefixes.
  ///
  /// "Atlanta nightlife" → atlanta, nightlife, atlantanightlife
  /// "#Atlanta" → atlanta
  static List<String> tokens(String query) {
    final cleaned = query.trim().toLowerCase().replaceAll('#', ' ');
    final words = cleaned
        .split(RegExp(r'[^a-z0-9_]+'))
        .where((part) => part.length >= 2 && part.length <= 30)
        .take(6)
        .toList();
    if (words.isEmpty) return const [];
    final out = <String>{...words};
    if (words.length >= 2) {
      final joined = words.join();
      if (joined.length <= 30) out.add(joined);
    }
    return out.toList();
  }

  static List<CommunityNewsPost> sortTop(List<CommunityNewsPost> posts) {
    final copy = [...posts];
    copy.sort((a, b) {
      final scoreA = a.sparkCount + a.repostCount * 4;
      final scoreB = b.sparkCount + b.repostCount * 4;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }
}

class HashtagService {
  HashtagService._();

  static final _client = Supabase.instance.client;

  static Future<List<CommunityNewsPost>> fetchPostsByTag(
    String tag, {
    int limit = 30,
    bool vueOnly = false,
  }) async {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    try {
      final tagRow = await _client
          .from('hashtags')
          .select('id')
          .eq('tag', normalized)
          .maybeSingle();

      if (tagRow != null) {
        final hashtagId = tagRow['id'] as String;
        final postIds = <String>{};
        try {
          final links = await _client
              .from('post_hashtags')
              .select('post_id')
              .eq('hashtag_id', hashtagId)
              .limit(limit);
          postIds.addAll(links.map((row) => row['post_id'] as String));
        } catch (_) {}
        try {
          final contentLinks = await _client
              .from('content_hashtags')
              .select('content_id')
              .eq('hashtag_id', hashtagId)
              .eq('content_type', 'post')
              .limit(limit);
          postIds.addAll(
            contentLinks.map((row) => row['content_id'] as String),
          );
        } catch (_) {}
        if (postIds.isNotEmpty) {
          final posts = await _fetchPostsByIds(postIds.take(limit).toList());
          return _filterPosts(posts, vueOnly: vueOnly);
        }
      }
    } catch (_) {}

    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, author_id, business_id, community_id')
          .eq('status', 'approved')
          .ilike('body', '%#$normalized%')
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = await CommunityNewsService.mapPostRowsPublic(rows);
      return _filterPosts(posts, vueOnly: vueOnly);
    } catch (_) {
      return const [];
    }
  }

  static List<CommunityNewsPost> _filterPosts(
    List<CommunityNewsPost> posts, {
    required bool vueOnly,
  }) {
    if (!vueOnly) return posts;
    return [
      for (final post in posts)
        if (post.publishDestination.appearsOnVue) post,
    ];
  }

  /// Active Stories that include the hashtag in caption/overlays metadata.
  static Future<List<StoryItem>> fetchStoriesByTag(
    String tag, {
    int limit = 20,
  }) async {
    final normalized = tag.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    try {
      final tagRow = await _client
          .from('hashtags')
          .select('id')
          .eq('tag', normalized)
          .maybeSingle();
      if (tagRow == null) return const [];

      final links = await _client
          .from('content_hashtags')
          .select('content_id')
          .eq('hashtag_id', tagRow['id'] as String)
          .eq('content_type', 'story')
          .order('created_at', ascending: false)
          .limit(limit);
      final ids = links.map((row) => row['content_id'] as String).toSet();
      if (ids.isEmpty) return const [];

      final rings = await StoryService.fetchActiveRings();
      final matches = <StoryItem>[];
      for (final ring in rings) {
        for (final story in ring.stories) {
          if (ids.contains(story.id)) matches.add(story);
        }
      }
      return matches;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<TrendingHashtag>> fetchTrending({
    int hours = 48,
    int limit = 20,
    bool nearYou = false,
  }) async {
    String? city;
    String? state;
    if (nearYou) {
      final prefs = await UserPreferencesService.fetch();
      city = prefs.locationCity;
      state = prefs.locationState;
    }
    try {
      final rows = await _client.rpc(
        'fetch_trending_hashtags',
        params: {
          'p_hours': hours,
          'p_limit': limit,
          'p_city': city,
          'p_state': state,
        },
      );
      if (rows is! List) return const [];
      return [
        for (final row in rows)
          TrendingHashtag(
            tag: row['tag'] as String,
            score: (row['score'] as num?)?.toDouble() ?? 0,
            uniqueActors: (row['unique_actors'] as num?)?.toInt() ?? 0,
            recentUses: (row['recent_uses'] as num?)?.toInt() ?? 0,
            useCount: (row['use_count'] as num?)?.toInt() ?? 0,
          ),
      ];
    } catch (_) {
      // Fallback: lifetime use_count until migration is applied.
      try {
        final rows = await _client
            .from('hashtags')
            .select('tag, use_count')
            .order('use_count', ascending: false)
            .limit(limit);
        return [
          for (final row in rows)
            TrendingHashtag(
              tag: row['tag'] as String,
              score: (row['use_count'] as num?)?.toDouble() ?? 0,
              uniqueActors: 0,
              recentUses: 0,
              useCount: (row['use_count'] as num?)?.toInt() ?? 0,
            ),
        ];
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<List<CommunityNewsPost>> _fetchPostsByIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return const [];
    final rows = await _client
        .from('community_news_posts')
        .select('id, body, created_at, author_id, business_id, community_id')
        .inFilter('id', postIds)
        .eq('status', 'approved')
        .order('created_at', ascending: false);
    return await CommunityNewsService.mapPostRowsPublic(rows);
  }
}
