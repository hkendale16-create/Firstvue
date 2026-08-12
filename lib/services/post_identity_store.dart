import 'package:shared_preferences/shared_preferences.dart';

import '../models/post_identity.dart';

/// Persists the user's last selected "Post as" identity across sessions.
class PostIdentityStore {
  PostIdentityStore._();

  static const _prefsKey = 'firstvue_post_identity_key';

  static Future<String?> loadSelectedKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  static Future<void> saveSelected(PostIdentityOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, option.storageKey);
  }
}
