import 'dart:io';

import 'package:firstvue/services/post_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PostMetadataService.parse extracts hashtags and mentions', () {
    final parsed = PostMetadataService.parse(
      'Hello @kendale check out #FirstVue and #barber life with @some_user',
    );

    expect(parsed.hashtags, containsAll(['firstvue', 'barber']));
    expect(parsed.mentionUsernames, containsAll(['kendale', 'some_user']));
  });

  test('hashtag parse is case-insensitive and de-duplicates', () {
    final parsed = PostMetadataService.parse(
      'Best rooftop #Atlanta #Nightlife #atlanta #Food',
    );
    expect(parsed.hashtags, containsAll(['atlanta', 'nightlife', 'food']));
    expect(parsed.hashtags.where((tag) => tag == 'atlanta').length, 1);
  });

  test('syncForPost prefers global sync_content_hashtags RPC', () {
    final src =
        File('lib/services/post_metadata_service.dart').readAsStringSync();
    expect(src, contains('sync_content_hashtags'));
    expect(src, contains("'p_content_type': contentType"));
    expect(src, contains("'p_content_id': contentId"));
    // Legacy post hashtag RPC remains as a fallback for older backends.
    expect(src, contains('sync_post_hashtags'));
    expect(src, contains("'p_post_id': contentId"));
    expect(src, contains("'p_body': body"));
  });

  test('mentions resolve through EntityHandleService and skip null profile ids', () {
    final src =
        File('lib/services/post_metadata_service.dart').readAsStringSync();
    expect(src, contains('EntityHandleService.lookup'));
    expect(src, contains("payload['mentioned_profile_id'] = lookup.entityId"));
    expect(src, contains("payload['mentioned_business_id'] = lookup.entityId"));
    expect(src, isNot(contains('mentioned_profile_id: null')));
    expect(
      src,
      isNot(contains("lookup.entityType == EntityHandleType.user ? lookup.entityId : null")),
    );
  });
}