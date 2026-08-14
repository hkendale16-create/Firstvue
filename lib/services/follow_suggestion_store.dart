import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Per-user persistence for dismissed Consider Following cards.
class FollowSuggestionStore {
  FollowSuggestionStore._();

  static const _prefsKey = 'firstvue_dismissed_follow_suggestions';

  static Future<Set<String>> loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(_prefsKey)};
  }

  static Future<void> dismiss(
    String targetId, {
    String type = 'business',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = {...?prefs.getStringList(_prefsKey), targetId};
    await prefs.setStringList(_prefsKey, current.toList());
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('dismissed_follow_suggestions')
          .upsert({
            'profile_id': user.id,
            'target_id': targetId,
            'target_type': type,
          });
    } catch (_) {}
  }
}
