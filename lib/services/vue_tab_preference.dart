import 'package:shared_preferences/shared_preferences.dart';

import 'discovery_feed_service.dart';

/// Remembers the selected VUE tab (For You / Nearby / Trending) across ordinary
/// navigation without waiting on a prefs round-trip.
class VueTabPreference {
  VueTabPreference._();

  static const prefsKey = 'firstvue_vue_feed_tab';

  static VueFeedMode _cached = VueFeedMode.forYou;
  static bool _hydrated = false;

  static VueFeedMode get current => _cached;

  static VueFeedMode parse(String? raw) {
    return switch ((raw ?? '').trim()) {
      'nearby' => VueFeedMode.nearby,
      'trending' => VueFeedMode.trending,
      _ => VueFeedMode.forYou,
    };
  }

  static Future<VueFeedMode> load() async {
    if (_hydrated) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cached = parse(prefs.getString(prefsKey));
    } catch (_) {}
    _hydrated = true;
    return _cached;
  }

  static Future<void> save(VueFeedMode mode) async {
    _cached = mode;
    _hydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (_) {}
  }
}
