import 'package:shared_preferences/shared_preferences.dart';

/// Top-level FirstVue experience mode: existing social (VUE) vs LIVE discovery.
enum FirstVueExperienceMode { vue, live }

/// Remembers VUE | LIVE selection locally (no server write).
class LiveModePreference {
  LiveModePreference._();

  static const prefsKey = 'firstvue_experience_mode';

  static FirstVueExperienceMode _cached = FirstVueExperienceMode.vue;
  static bool _hydrated = false;

  static FirstVueExperienceMode get current => _cached;

  static bool get isLive => _cached == FirstVueExperienceMode.live;

  static FirstVueExperienceMode parse(String? raw) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'live' => FirstVueExperienceMode.live,
      _ => FirstVueExperienceMode.vue,
    };
  }

  static Future<FirstVueExperienceMode> load() async {
    if (_hydrated) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cached = parse(prefs.getString(prefsKey));
    } catch (_) {
      _cached = FirstVueExperienceMode.vue;
    }
    _hydrated = true;
    return _cached;
  }

  static Future<void> save(FirstVueExperienceMode mode) async {
    _cached = mode;
    _hydrated = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, mode.name);
    } catch (_) {}
  }

  /// Test helper — resets in-memory cache between widget tests.
  static void debugReset({
    FirstVueExperienceMode mode = FirstVueExperienceMode.vue,
  }) {
    _cached = mode;
    _hydrated = false;
  }
}
