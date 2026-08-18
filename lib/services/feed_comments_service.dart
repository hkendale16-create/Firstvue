import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';
import 'community_news_service.dart';
import 'post_metadata_service.dart';
import 'profile_cards.dart';

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

  FeedComment copyWith({
    int? sparkCount,
    bool? sparkedByMe,
  }) {
    return FeedComment(
      id: id,
      body: body,
      authorName: authorName,
      authorId: authorId,
      createdAt: createdAt,
      isMine: isMine,
      parentId: parentId,
      sparkCount: sparkCount ?? this.sparkCount,
      sparkedByMe: sparkedByMe ?? this.sparkedByMe,
    );
  }
}

class FeedCommentsService {
  FeedCommentsService._();

  static final _client = Supabase.instance.client;

  static const migrationHint =
      'Comments need Supabase migration 20260816_feed_comments_text_media_id.sql. '
      'Run it in the Supabase SQL Editor (or apply_pending_migrations.sql).';

  static String userMessageForError(Object error) {
    final text = error.toString().toLowerCase();
    if (_looksLikeTextMediaIdMigrationMissing(text)) {
      return migrationHint;
    }
    if (error is FeedCommentsAuthException) {
      return 'Sign in to view and post comments.';
    }
    if (error is PostgrestException) {
      final code = error.code?.toLowerCase() ?? '';
      if (code == '42501' || text.contains('row-level security')) {
        return 'You do not have permission to access these comments.';
      }
    }
    return 'Unable to load comments right now. Please try again.';
  }

  static bool _looksLikeTextMediaIdMigrationMissing(String text) {
    return text.contains('invalid input syntax for type uuid') ||
        text.contains('operator does not exist: uuid = text') ||
        text.contains('operator does not exist: text = uuid') ||
        (text.contains('media_id') &&
            (text.contains('uuid') || text.contains('type')));
  }

  /// All replies under a top-level comment, including nested replies.
  static List<FeedComment> collectThreadReplies(
    List<FeedComment> all,
    String rootId,
  ) {
    final direct =
        all.where((comment) => comment.parentId == rootId).toList();
    final result = <FeedComment>[];
    for (final reply in direct) {
      result.add(reply);
      result.addAll(collectThreadReplies(all, reply.id));
    }
    return result;
  }

  static Future<List<FeedComment>> fetchComments(String mediaId) async {
    final me = _client.auth.currentUser?.id;
    try {
      final rows = await _client
          .from('feed_comments')
          .select('id, body, created_at, author_id, parent_id')
          .eq('media_id', mediaId)
          .order('created_at', ascending: true);

      return await _mapCommentRows(rows, me: me);
    } on PostgrestException catch (error) {
      throw FeedCommentsException(userMessageForError(error), cause: error);
    }
  }

  static Future<FeedComment?> commentFromRealtimeRecord(
    Map<String, dynamic> record,
  ) async {
    final me = _client.auth.currentUser?.id;
    final comments = await _mapCommentRows([record], me: me);
    return comments.isEmpty ? null : comments.first;
  }

  static Future<List<FeedComment>> _mapCommentRows(
    List<dynamic> rows, {
    required String? me,
  }) async {
    if (rows.isEmpty) return const [];

    final commentIds = rows.map((row) => row['id'] as String).toList();
    final authorIds = rows
        .map((row) => row['author_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final authorNames = await _fetchProfileNames(authorIds);
    final sparkCounts = await _fetchSparkCounts(commentIds);
    final mySparks = me == null
        ? const <String>{}
        : await _fetchMySparks(commentIds, me);

    return rows
        .map(
          (row) => _commentFromRow(
            row as Map<String, dynamic>,
            me: me,
            authorNames: authorNames,
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

  static Future<Map<String, String>> _fetchProfileNames(
    List<String> authorIds,
  ) async {
    if (authorIds.isEmpty) return {};
    try {
      return await ProfileCards.displayNames(authorIds);
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
    Map<String, String> authorNames = const {},
    Map<String, int> sparkCounts = const {},
    Set<String> mySparks = const {},
  }) {
    final authorId = row['author_id'] as String?;
    final id = row['id'] as String;
    return FeedComment(
      id: id,
      body: row['body'] as String,
      authorName: authorId == null
          ? 'FirstVue member'
          : (authorNames[authorId] ?? 'FirstVue member'),
      authorId: authorId,
      createdAt: DateTime.parse(row['created_at'] as String),
      isMine: authorId == me,
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

    try {
      final inserted = await _client
          .from('feed_comments')
          .insert({
            'media_id': mediaId,
            'author_id': user.id,
            'body': trimmed,
            'parent_id': parentId,
          })
          .select('id, body, created_at, author_id, parent_id')
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
            payload: {
              'comment_id': inserted['id'],
              'media_id': mediaId,
              if (mediaId.startsWith('news-post:'))
                'post_id': CommunityNewsService.normalizePostId(
                  mediaId.substring('news-post:'.length),
                ),
            },
          );
        }
      } else if (mediaId.startsWith('news-post:')) {
        final postId = CommunityNewsService.normalizePostId(
          mediaId.substring('news-post:'.length),
        );
        try {
          final post = await _client
              .from('community_news_posts')
              .select('author_id')
              .eq('id', postId)
              .maybeSingle();
          final recipient = post?['author_id'] as String?;
          if (recipient != null && recipient != user.id) {
            await ActivityNotificationsService.notifyUser(
              userId: recipient,
              type: 'news_comment',
              title: 'New comment on your post',
              body: trimmed,
              payload: {'post_id': postId, 'comment_id': inserted['id']},
            );
          }
        } catch (_) {}
      }

      try {
        await PostMetadataService.syncForContent(
          contentType: 'comment',
          contentId: inserted['id'] as String,
          body: trimmed,
        );
      } catch (_) {}

      final authorNames = await _fetchProfileNames([user.id]);
      return _commentFromRow(
        inserted,
        me: user.id,
        authorNames: authorNames,
      );
    } on PostgrestException catch (error) {
      throw FeedCommentsException(userMessageForError(error), cause: error);
    }
  }

  static Future<FeedComment> toggleSpark(FeedComment comment) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw const FeedCommentsAuthException();

    final optimistic = comment.copyWith(
      sparkedByMe: !comment.sparkedByMe,
      sparkCount: comment.sparkCount + (comment.sparkedByMe ? -1 : 1),
    );

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
          String? postId;
          try {
            final row = await _client
                .from('feed_comments')
                .select('media_id')
                .eq('id', comment.id)
                .maybeSingle();
            final mediaId = row?['media_id'] as String?;
            if (mediaId != null && mediaId.startsWith('news-post:')) {
              postId = CommunityNewsService.normalizePostId(
                mediaId.substring('news-post:'.length),
              );
            }
          } catch (_) {}
          await ActivityNotificationsService.notifyUser(
            userId: authorId,
            type: 'comment_spark',
            title: 'Someone sparked your comment',
            body: comment.body,
            payload: {
              'comment_id': comment.id,
              'post_id': ?postId,
            },
          );
        }
      }
      return optimistic;
    } catch (_) {
      return comment;
    }
  }
}

class FeedCommentsAuthException implements Exception {
  const FeedCommentsAuthException();
}

class FeedCommentsException implements Exception {
  final String message;
  final Object? cause;

  const FeedCommentsException(this.message, {this.cause});

  @override
  String toString() => message;
}
