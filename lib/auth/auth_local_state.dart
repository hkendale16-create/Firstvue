import 'package:shared_preferences/shared_preferences.dart';

import '../services/cache/device_cache_hub.dart';

/// Clears signed-in-only local caches so a later guest cannot restore them.
class AuthLocalState {
  AuthLocalState._();

  static const pendingLegalAcceptanceKey = 'firstvue_pending_legal_accept';

  static const _protectedPrefixes = [
    'vue_last_featured_creator_',
    'firstvue_post_identity',
    'firstvue_recent_categories',
    'firstvue_follow_suggest',
    'firstvue_interaction',
    'firstvue_feed_page_',
    'firstvue_growth_',
    'firstvue_invite_code_',
  ];

  static const _protectedKeys = {
    'firstvue_post_identity_key',
    'firstvue_show_email_on_profile',
    'firstvue_vue_feed_tab',
    'firstvue_feed_page_main_v1',
    pendingLegalAcceptanceKey,
    'firstvue_invite_attributed',
  };

  static Future<void> markPendingLegalAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pendingLegalAcceptanceKey, true);
  }

  static Future<void> clearPendingLegalAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingLegalAcceptanceKey);
  }

  static Future<bool> consumePendingLegalAcceptance() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(pendingLegalAcceptanceKey) ?? false;
    if (pending) {
      await prefs.remove(pendingLegalAcceptanceKey);
    }
    return pending;
  }

  static Future<void> clearProtected() async {
    DeviceCacheHub.clearAll();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      final protected =
          _protectedKeys.contains(key) ||
          _protectedPrefixes.any((prefix) => key.startsWith(prefix));
      if (protected) {
        await prefs.remove(key);
      }
    }
  }
}
