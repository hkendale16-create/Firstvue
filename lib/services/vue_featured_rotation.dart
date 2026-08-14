import 'package:shared_preferences/shared_preferences.dart';

import '../services/discovery_feed_service.dart';

/// Remembers which creator occupied the leading VUE 2x2 tile per feed mode.
class VueFeaturedRotation {
  VueFeaturedRotation._();

  static const _keyPrefix = 'vue_last_featured_creator_';

  static String _key(VueFeedMode mode) => '$_keyPrefix${mode.name}';

  static Future<String?> lastCreator(VueFeedMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(mode));
  }

  static Future<void> remember(VueFeedMode mode, String creatorId) async {
    if (creatorId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(mode), creatorId);
  }
}
