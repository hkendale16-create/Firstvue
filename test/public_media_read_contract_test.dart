import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String publicMediaSql;
  late String readinessSql;

  setUpAll(() {
    publicMediaSql = File(
      'supabase/migrations/20260918_public_media_read.sql',
    ).readAsStringSync();
    readinessSql = File(
      'supabase/migrations/20260923_prototype_readiness_hardening.sql',
    ).readAsStringSync();
  });

  test('public media read does not disable RLS', () {
    expect(
      publicMediaSql.toLowerCase().contains('disable row level security'),
      isFalse,
    );
    expect(
      readinessSql.toLowerCase().contains('disable row level security'),
      isFalse,
    );
  });

  test('profile and post media storage reads include anon', () {
    expect(publicMediaSql, contains("to anon, authenticated"));
    expect(publicMediaSql, contains("bucket_id = 'profile-media'"));
    expect(publicMediaSql, contains("bucket_id = 'community-news-media'"));
    expect(publicMediaSql, contains("bucket_id = 'business-media'"));
    expect(publicMediaSql.contains("bucket_id = 'fv-msg-media'"), isFalse);
  });

  test('prototype readiness scopes profile-media reads to linked objects', () {
    expect(readinessSql, contains('Scoped read profile media files'));
    expect(readinessSql, contains('profile_media media'));
    expect(readinessSql, contains('story.media_path'));
    expect(readinessSql, contains('sync_post_hashtags'));
    expect(readinessSql, contains('set_post_reaction'));
    expect(readinessSql, contains('fv_msg_enforce_send_guards'));
  });

  test('profile screen shows stored bio instead of a placeholder', () {
    final src = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(src, isNot(contains("bio: 'Discovering local talent'")));
    expect(src, contains('bio: _bio'));
  });

  test('start over control is removed from profile and settings', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    final settings =
        File('lib/widgets/firstvue_settings_drawer.dart').readAsStringSync();
    expect(profile.contains('Start over'), isFalse);
    expect(settings.contains('Start over'), isFalse);
    expect(File('lib/widgets/start_over_flow.dart').existsSync(), isFalse);
  });
}
