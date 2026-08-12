import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';
import 'username_service.dart';

class ParsedPostMetadata {
  final List<String> hashtags;
  final List<String> mentionUsernames;

  const ParsedPostMetadata({
    this.hashtags = const [],
    this.mentionUsernames = const [],
  });
}

class PostMetadataService {
  PostMetadataService._();

  static final _client = Supabase.instance.client;

  static final _hashtagPattern = RegExp(r'#([a-zA-Z0-9_]{2,30})');
  static final _mentionPattern = RegExp(r'@([a-zA-Z0-9_]{3,30})');

  static ParsedPostMetadata parse(String body) {
    final tags = <String>{};
    final mentions = <String>{};

    for (final match in _hashtagPattern.allMatches(body)) {
      tags.add(match.group(1)!.toLowerCase());
    }
    for (final match in _mentionPattern.allMatches(body)) {
      mentions.add(match.group(1)!.toLowerCase());
    }

    return ParsedPostMetadata(
      hashtags: tags.toList(),
      mentionUsernames: mentions.toList(),
    );
  }

  static Future<void> syncForPost(String postId, String body) async {
    final parsed = parse(body);
    if (parsed.hashtags.isEmpty && parsed.mentionUsernames.isEmpty) return;

    for (final tag in parsed.hashtags) {
      await _linkHashtag(postId, tag);
    }
    for (final username in parsed.mentionUsernames) {
      await _linkMention(postId, username);
    }
  }

  static Future<void> _linkHashtag(String postId, String tag) async {
    try {
      final existing = await _client
          .from('hashtags')
          .select('id')
          .eq('tag', tag)
          .maybeSingle();

      String hashtagId;
      if (existing != null) {
        hashtagId = existing['id'] as String;
      } else {
        final inserted = await _client
            .from('hashtags')
            .insert({'tag': tag})
            .select('id')
            .single();
        hashtagId = inserted['id'] as String;
      }

      try {
        await _client.from('post_hashtags').insert({
          'post_id': postId,
          'hashtag_id': hashtagId,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
    } catch (_) {}
  }

  static Future<void> _linkMention(String postId, String username) async {
    try {
      final profileId = await UsernameService.lookupProfileId(username);
      if (profileId == null) return;

      await _client.from('post_mentions').insert({
        'post_id': postId,
        'mentioned_profile_id': profileId,
        'mention_text': '@${UsernameService.normalize(username) ?? username}',
      });

      final me = _client.auth.currentUser?.id;
      if (me != null && profileId != me) {
        await ActivityNotificationsService.notifyUser(
          userId: profileId,
          type: 'mention',
          title: 'You were mentioned in a post',
          body: '@${UsernameService.normalize(username) ?? username}',
          payload: {'post_id': postId, 'profile_id': me},
        );
      }
    } catch (_) {}
  }
}
