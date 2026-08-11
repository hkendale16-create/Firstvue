import 'package:supabase_flutter/supabase_flutter.dart';

class FeedComment {
  final String id;
  final String body;
  final String authorName;
  final DateTime createdAt;
  final bool isMine;

  const FeedComment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.createdAt,
    required this.isMine,
  });
}

class FeedCommentsService {
  FeedCommentsService._();

  static final _client = Supabase.instance.client;

  static Future<List<FeedComment>> fetchComments(String mediaId) async {
    final me = _client.auth.currentUser?.id;
    final rows = await _client
        .from('feed_comments')
        .select('id, body, created_at, author_id, profiles(display_name)')
        .eq('media_id', mediaId)
        .order('created_at', ascending: true);

    return rows.map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      return FeedComment(
        id: row['id'] as String,
        body: row['body'] as String,
        authorName: (profile?['display_name'] as String?) ?? 'FirstVue member',
        createdAt: DateTime.parse(row['created_at'] as String),
        isMine: row['author_id'] == me,
      );
    }).toList();
  }

  static Future<void> postComment({
    required String mediaId,
    required String body,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw const FeedCommentsAuthException();
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    await _client.from('feed_comments').insert({
      'media_id': mediaId,
      'author_id': me,
      'body': trimmed,
    });
  }
}

class FeedCommentsAuthException implements Exception {
  const FeedCommentsAuthException();
}
