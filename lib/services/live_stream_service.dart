import 'package:supabase_flutter/supabase_flutter.dart';

class LiveStreamEligibility {
  final bool isVerified;
  final int followerCount;
  final bool isEligible;
  final DateTime checkedAt;

  const LiveStreamEligibility({
    required this.isVerified,
    required this.followerCount,
    required this.isEligible,
    required this.checkedAt,
  });

  static const minFollowers = 20;
}

class LiveStreamService {
  LiveStreamService._();

  static final _client = Supabase.instance.client;

  static Future<LiveStreamEligibility?> fetchMyEligibility() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      await _client.rpc(
        'refresh_live_eligibility',
        params: {'p_profile_id': user.id},
      );
    } catch (_) {}

    try {
      final row = await _client
          .from('live_stream_eligibility')
          .select('is_verified, follower_count, is_eligible, checked_at')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (row == null) return null;

      final checkedRaw = row['checked_at'];
      return LiveStreamEligibility(
        isVerified: row['is_verified'] as bool? ?? false,
        followerCount: row['follower_count'] as int? ?? 0,
        isEligible: row['is_eligible'] as bool? ?? false,
        checkedAt: checkedRaw is String
            ? DateTime.tryParse(checkedRaw) ?? DateTime.now()
            : DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
