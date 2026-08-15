import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';

/// Loads server-side monetization flags and merges with compile-time defaults.
class MonetizationFlagsService {
  MonetizationFlagsService._();

  static SupabaseClient get _client => Supabase.instance.client;
  static Map<String, bool>? _cache;
  static DateTime? _cachedAt;

  static Future<Map<String, bool>> fetchFlags({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _cache != null &&
        _cachedAt != null &&
        now.difference(_cachedAt!) < const Duration(minutes: 5)) {
      return _cache!;
    }

    try {
      final rows = await _client
          .from('monetization_feature_flags')
          .select('flag_key, enabled');
      final map = <String, bool>{
        for (final key in MonetizationFlagKeys.all) key: false,
      };
      for (final row in rows) {
        final key = row['flag_key'] as String?;
        if (key == null) continue;
        map[key] = row['enabled'] as bool? ?? false;
      }
      _cache = map;
      _cachedAt = now;
      return map;
    } catch (_) {
      // Offline / migration not applied yet — compile-time only.
      final fallback = {
        for (final key in MonetizationFlagKeys.all)
          key: FeatureFlags.resolve(key),
      };
      _cache = fallback;
      _cachedAt = now;
      return fallback;
    }
  }

  static Future<bool> isEnabled(String flagKey) async {
    final flags = await fetchFlags();
    return FeatureFlags.resolve(flagKey, serverEnabled: flags[flagKey]);
  }

  static Future<bool> get vueBounties async =>
      isEnabled(MonetizationFlagKeys.vueBounties);

  static Future<bool> get bountyFunding async =>
      isEnabled(MonetizationFlagKeys.bountyFunding);

  static Future<bool> get creatorPayouts async =>
      isEnabled(MonetizationFlagKeys.creatorPayouts);

  static Future<bool> get affiliateRewards async =>
      isEnabled(MonetizationFlagKeys.affiliateRewards);

  static Future<bool> get businessSubscriptions async =>
      isEnabled(MonetizationFlagKeys.businessSubscriptions);

  static void clearCache() {
    _cache = null;
    _cachedAt = null;
  }
}
