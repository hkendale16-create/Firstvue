import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260918_public_media_read.sql',
    ).readAsStringSync();
  });

  test('public media read does not disable RLS', () {
    expect(sql.toLowerCase().contains('disable row level security'), isFalse);
  });

  test('profile and post media storage reads include anon', () {
    expect(sql, contains("to anon, authenticated"));
    expect(sql, contains("bucket_id = 'profile-media'"));
    expect(sql, contains("bucket_id = 'community-news-media'"));
    expect(sql, contains("bucket_id = 'business-media'"));
    expect(sql.contains("bucket_id = 'fv-msg-media'"), isFalse);
  });

  test('profile screen shows stored bio instead of a placeholder', () {
    final src = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(src, isNot(contains("bio: 'Discovering local talent'")));
    expect(src, contains('bio: _bio'));
  });
}
