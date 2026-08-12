import 'package:supabase_flutter/supabase_flutter.dart';

class RepostService {
  RepostService._();

  static final _client = Supabase.instance.client;

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

  static Future<bool> hasReposted(String postId) async {
    final me = _client.auth.currentUser;
    if (me == null) return false;

    try {
      final row = await _client
          .from('post_reposts')
          .select('id')
          .eq('user_id', me.id)
          .eq('post_id', postId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<int> fetchRepostCount(String postId) async {
    if (postId.trim().isEmpty) return 0;
    try {
      final rows = await _client
          .from('post_reposts')
          .select('id')
          .eq('post_id', postId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<Set<String>> fetchMyRepostedIds(List<String> postIds) async {
    final me = _client.auth.currentUser;
    if (me == null || postIds.isEmpty) return {};

    try {
      final rows = await _client
          .from('post_reposts')
          .select('post_id')
          .eq('user_id', me.id)
          .inFilter('post_id', postIds);
      return rows.map((row) => row['post_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> repost(String postId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to repost.');

    await _ensureProfile(me);

    try {
      await _client.from('post_reposts').insert({
        'user_id': me.id,
        'post_id': postId,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
  }

  static Future<void> undoRepost(String postId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to undo repost.');

    await _client
        .from('post_reposts')
        .delete()
        .eq('user_id', me.id)
        .eq('post_id', postId);
  }

  static Future<bool> toggleRepost(String postId, {required bool currentlyReposted}) async {
    if (currentlyReposted) {
      await undoRepost(postId);
      return false;
    }
    await repost(postId);
    return true;
  }
}
