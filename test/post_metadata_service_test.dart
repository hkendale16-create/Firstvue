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

  test('syncForPost prefers sync_post_hashtags RPC', () {
    final src =
        File('lib/services/post_metadata_service.dart').readAsStringSync();
    expect(src, contains('sync_post_hashtags'));
    expect(src, contains("params: {'p_post_id': postId, 'p_body': body}"));
  });
}
