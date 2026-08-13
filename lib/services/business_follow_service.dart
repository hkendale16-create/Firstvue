import 'package:supabase_flutter/supabase_flutter.dart';

/// Follow / unfollow FirstVue businesses via `business_follows`.
class BusinessFollowService {
  BusinessFollowService._();

  static final _client = Supabase.instance.client;

  static Future<bool> isFollowing(String businessId) async {
    final me = _client.auth.currentUser;
    if (me == null || businessId.trim().isEmpty) return false;
    try {
      final row = await _client
          .from('business_follows')
          .select('business_id')
          .eq('business_id', businessId)
          .eq('profile_id', me.id)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<int> followerCount(String businessId) async {
    if (businessId.trim().isEmpty) return 0;
    try {
      final rows = await _client
          .from('business_follows')
          .select('profile_id')
          .eq('business_id', businessId);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> follow(String businessId) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to follow businesses.');
    }
    try {
      await _client.from('business_follows').insert({
        'business_id': businessId,
        'profile_id': me.id,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
    return true;
  }

  static Future<bool> unfollow(String businessId) async {
    final me = _client.auth.currentUser;
    if (me == null) {
      throw const AuthException('Sign in to unfollow businesses.');
    }
    await _client
        .from('business_follows')
        .delete()
        .eq('business_id', businessId)
        .eq('profile_id', me.id);
    return false;
  }

  static Future<bool> toggle(String businessId, {required bool currentlyFollowing}) async {
    if (currentlyFollowing) {
      return unfollow(businessId);
    }
    return follow(businessId);
  }
}
