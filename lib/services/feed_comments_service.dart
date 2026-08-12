import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';

class FeedComment {
  final String id;
  final String body;
  final String authorName;
  final String? authorId;
  final DateTime createdAt;
  final bool isMine;
  final String? parentId;
  final int sparkCount;
  final bool sparkedByMe;

  const FeedComment({
    required this.id,
    required this.body,
    required this.authorName,
    required this.authorId,
    required this.createdAt,
    required this.isMine,
    required this.parentId,
    required this.sparkCount,
    required this.sparkedByMe,
  });
}

class FeedCommentsService {
  FeedCommentsService._();

  static final _client = Supabase.instance.client;

  static Future<List<FeedComment>> fetchComments(String mediaId) async {
    final me = _client.auth.currentUser?.id;
    final rows = await _client
        .from('feed_comments')
        .select('id, body, created_at, author_id, parent_id, profiles(display_name)')
        .eq('media_id', mediaId)
        .order('created_at', ascending: true);

    final commentIds = rows.map((row) => row['id'] as String).toList();
    final sparkCounts = await _fetchSparkCounts(commentIds);
    final mySparks = me == null
        ? const <String>{}
        : await _fetchMySparks(commentIds, me);

    return rows
        .map(
          (row) => _commentFromRow(
            row,
            me: me,
            sparkCounts: sparkCounts,
            mySparks: mySparks,
          ),
        )
        .toList();
  }

  static Future<Map<String, int>> _fetchSparkCounts(List<String> commentIds) async {
    if (commentIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('feed_comment_sparks')
          .select('comment_id')
          .inFilter('comment_id', commentIds);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['comment_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _fetchMySparks(
    List<String> commentIds,
    String userId,
  ) async {
    if (commentIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('feed_comment_sparks')
          .select('comment_id')
          .eq('user_id', userId)
          .inFilter('comment_id', commentIds);
      return rows.map((row) => row['comment_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> _ensureProfile(User user) async {
    final displayName = user.email?.split('@').first;
    try {
      await _client.rpc(
        'ensure_user_profile',
        params: {'display_name': displayName},
      );
    } catch (_) {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        await _client.from('profiles').insert({
          'id': user.id,
          'display_name': displayName,
        });
      }
    }
  }

  static FeedComment _commentFromRow(
    Map<String, dynamic> row, {
    required String? me,
    Map<String, int> sparkCounts = const {},
    Set<String> mySparks = const {},
  }) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final id = row['id'] as String;
    return FeedComment(
      id: id,
      body: row['body'] as String,
      authorName: (profile?['display_name'] as String?) ?? 'FirstVue member',
      authorId: row['author_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      isMine: row['author_id'] == me,
      parentId: row['parent_id'] as String?,
      sparkCount: sparkCounts[id] ?? 0,
      sparkedByMe: mySparks.contains(id),
    );
  }

  static Future<FeedComment> postComment({
    required String mediaId,
    required String body,
    String? parentId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const FeedCommentsAuthException();
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Comment body cannot be empty.');
    }

    await _ensureProfile(user);

    final inserted = await _client
        .from('feed_comments')
        .insert({
          'media_id': mediaId,
          'author_id': user.id,
          'body': trimmed,
          'parent_id': ?parentId,
        })
        .select(
          'id, body, created_at, author_id, parent_id, profiles(display_name)',
        )
        .single();

    if (parentId != null) {
      final parent = await _client
          .from('feed_comments')
          .select('author_id')
          .eq('id', parentId)
          .maybeSingle();
      final recipient = parent?['author_id'] as String?;
      if (recipient != null && recipient != user.id) {
        await ActivityNotificationsService.notifyUser(
          userId: recipient,
          type: 'comment_reply',
          title: 'New reply on your comment',
          body: trimmed,
          payload: {'comment_id': inserted['id'], 'media_id': mediaId},
        );
      }
    }

    return _commentFromRow(inserted, me: user.id);
  }

  static Future<void> toggleSpark(FeedComment comment) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw const FeedCommentsAuthException();
    try {
      if (comment.sparkedByMe) {
        await _client
            .from('feed_comment_sparks')
            .delete()
            .eq('comment_id', comment.id)
            .eq('user_id', me);
      } else {
        await _client.from('feed_comment_sparks').insert({
          'comment_id': comment.id,
          'user_id': me,
        });
        final authorId = comment.authorId;
        if (authorId != null && authorId != me) {
          await ActivityNotificationsService.notifyUser(
            userId: authorId,
            type: 'comment_spark',
            title: 'Someone sparked your comment',
            body: comment.body,
            payload: {'comment_id': comment.id},
          );
        }
      }
    } catch (_) {}
  }
}

class FeedCommentsAuthException implements Exception {
  const FeedCommentsAuthException();
}
