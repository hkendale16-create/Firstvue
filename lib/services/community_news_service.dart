import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';

class CommunityNewsPost {
  final String id;
  final String body;
  final String authorName;
  final String? businessName;
  final DateTime createdAt;
  final bool isMine;
  final int sparkCount;
  final bool sparkedByMe;

  const CommunityNewsPost({
    required this.id,
    required this.body,
    required this.authorName,
    required this.businessName,
    required this.createdAt,
    required this.isMine,
    required this.sparkCount,
    required this.sparkedByMe,
  });

  String get commentsMediaId => 'news-post:$id';
}

class CommunityNewsService {
  CommunityNewsService._();

  static final _client = Supabase.instance.client;

  static final _prototypePosts = [
    CommunityNewsPost(
      id: 'proto-news-1',
      body: 'New rooftop bar opening downtown this Friday — live music and happy hour.',
      authorName: 'FirstVue preview',
      businessName: null,
      createdAt: DateTime(2026, 1, 1),
      isMine: false,
      sparkCount: 12,
      sparkedByMe: false,
    ),
    CommunityNewsPost(
      id: 'proto-news-2',
      body: 'Weekend brunch special: \$15 bottomless mimosas at verified spots near you.',
      authorName: 'FirstVue preview',
      businessName: null,
      createdAt: DateTime(2026, 1, 1),
      isMine: false,
      sparkCount: 8,
      sparkedByMe: false,
    ),
  ];

  static Future<List<CommunityNewsPost>> fetchPosts({int limit = 20}) async {
    try {
      final rows = await _client
          .from('community_news_posts')
          .select(
            'id, body, created_at, author_id, businesses(name), profiles(display_name)',
          )
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      if (rows.isEmpty) return _prototypePostsWithDates();

      final me = _client.auth.currentUser?.id;
      final postIds = rows.map((row) => row['id'] as String).toList();
      final sparkCounts = await _fetchSparkCounts(postIds);
      final mySparks = me == null
          ? const <String>{}
          : await _fetchMySparks(postIds, me);

      return rows.map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final business = row['businesses'] as Map<String, dynamic>?;
        final id = row['id'] as String;
        return CommunityNewsPost(
          id: id,
          body: row['body'] as String,
          authorName:
              (profile?['display_name'] as String?) ?? 'FirstVue member',
          businessName: business?['name'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          isMine: row['author_id'] == me,
          sparkCount: sparkCounts[id] ?? 0,
          sparkedByMe: mySparks.contains(id),
        );
      }).toList();
    } catch (_) {
      return _prototypePostsWithDates();
    }
  }

  static List<CommunityNewsPost> _prototypePostsWithDates() {
    final now = DateTime.now();
    return _prototypePosts
        .map(
          (post) => CommunityNewsPost(
            id: post.id,
            body: post.body,
            authorName: post.authorName,
            businessName: post.businessName,
            createdAt: now.subtract(const Duration(hours: 2)),
            isMine: post.isMine,
            sparkCount: post.sparkCount,
            sparkedByMe: post.sparkedByMe,
          ),
        )
        .toList();
  }

  static Future<Map<String, int>> _fetchSparkCounts(List<String> postIds) async {
    if (postIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('community_news_post_sparks')
          .select('post_id')
          .inFilter('post_id', postIds);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['post_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _fetchMySparks(
    List<String> postIds,
    String userId,
  ) async {
    if (postIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('community_news_post_sparks')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      return rows.map((row) => row['post_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> createPost(String body, {String? businessId}) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to post.');
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    await _client.from('community_news_posts').insert({
      'author_id': me.id,
      'business_id': businessId,
      'body': trimmed,
      'status': 'approved',
    });
  }

  static Future<void> toggleSpark(CommunityNewsPost post) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw const AuthException('Sign in to spark posts.');
    if (post.id.startsWith('proto-')) return;
    try {
      if (post.sparkedByMe) {
        await _client
            .from('community_news_post_sparks')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', me);
      } else {
        await _client.from('community_news_post_sparks').insert({
          'post_id': post.id,
          'user_id': me,
        });
        if (post.isMine == false) {
          final author = await _client
              .from('community_news_posts')
              .select('author_id')
              .eq('id', post.id)
              .maybeSingle();
          final recipient = author?['author_id'] as String?;
          if (recipient != null && recipient != me) {
            await ActivityNotificationsService.notifyUser(
              userId: recipient,
              type: 'news_spark',
              title: 'Someone sparked your news post',
              body: post.body,
              payload: {'post_id': post.id},
            );
          }
        }
      }
    } catch (_) {}
  }
}
