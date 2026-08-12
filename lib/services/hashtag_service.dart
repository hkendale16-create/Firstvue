import 'package:supabase_flutter/supabase_flutter.dart';

import 'community_news_service.dart';

class HashtagService {
  HashtagService._();

  static final _client = Supabase.instance.client;

  static Future<List<CommunityNewsPost>> fetchPostsByTag(
    String tag, {
    int limit = 30,
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
        final links = await _client
            .from('post_hashtags')
            .select('post_id')
            .eq('hashtag_id', tagRow['id'] as String)
            .limit(limit);

        final postIds = links
            .map((row) => row['post_id'] as String)
            .toList();
        if (postIds.isNotEmpty) {
          return await _fetchPostsByIds(postIds);
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

      return await CommunityNewsService.mapPostRowsPublic(rows);
    } catch (_) {
      return const [];
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
