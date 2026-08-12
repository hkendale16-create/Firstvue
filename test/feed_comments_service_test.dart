import 'package:firstvue/services/feed_comments_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('FeedCommentsService.userMessageForError', () {
    test('detects missing text media_id migration from uuid cast error', () {
      const error = PostgrestException(
        message: 'invalid input syntax for type uuid: "news-post:abc"',
      );

      final message = FeedCommentsService.userMessageForError(error);

      expect(message, contains('20260816_feed_comments_text_media_id.sql'));
    });

    test('returns auth message for FeedCommentsAuthException', () {
      final message = FeedCommentsService.userMessageForError(
        FeedCommentsAuthException(),
      );

      expect(message, contains('Sign in'));
    });

    test('returns generic message for unknown errors', () {
      final message = FeedCommentsService.userMessageForError(
        Exception('network down'),
      );

      expect(message, contains('Unable to load comments'));
    });
  });

  group('FeedCommentsService.collectThreadReplies', () {
    test('includes nested replies under the root comment', () {
      final comments = [
        FeedComment(
          id: 'root',
          body: 'Top',
          authorName: 'A',
          authorId: 'u1',
          createdAt: DateTime(2026, 8, 12),
          isMine: false,
          parentId: null,
          sparkCount: 0,
          sparkedByMe: false,
        ),
        FeedComment(
          id: 'reply1',
          body: 'Reply',
          authorName: 'B',
          authorId: 'u2',
          createdAt: DateTime(2026, 8, 12),
          isMine: false,
          parentId: 'root',
          sparkCount: 0,
          sparkedByMe: false,
        ),
        FeedComment(
          id: 'nested',
          body: 'Nested',
          authorName: 'C',
          authorId: 'u3',
          createdAt: DateTime(2026, 8, 12),
          isMine: false,
          parentId: 'reply1',
          sparkCount: 0,
          sparkedByMe: false,
        ),
      ];

      final thread = FeedCommentsService.collectThreadReplies(comments, 'root');

      expect(thread.map((c) => c.id).toList(), ['reply1', 'nested']);
    });
  });

  group('FeedComment', () {
    test('copyWith updates spark fields', () {
      final comment = FeedComment(
        id: 'c1',
        body: 'Hello',
        authorName: 'Kendale',
        authorId: 'u1',
        createdAt: DateTime(2026, 8, 12),
        isMine: true,
        parentId: null,
        sparkCount: 1,
        sparkedByMe: false,
      );

      final updated = comment.copyWith(sparkedByMe: true, sparkCount: 2);

      expect(updated.sparkedByMe, isTrue);
      expect(updated.sparkCount, 2);
      expect(updated.body, 'Hello');
    });
  });
}
