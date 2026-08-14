import 'package:shared_preferences/shared_preferences.dart';

/// Clears signed-in-only local caches so a later guest cannot restore them.
class AuthLocalState {
  AuthLocalState._();

  static const _protectedPrefixes = [
    'vue_last_featured_creator_',
    'firstvue_post_identity',
    'firstvue_recent_categories',
    'firstvue_follow_suggest',
    'firstvue_interaction',
  ];

  static const _protectedKeys = {
    'firstvue_post_identity_key',
    'firstvue_show_email_on_profile',
  };

  static Future<void> clearProtected() async {
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
