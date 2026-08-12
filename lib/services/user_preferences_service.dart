import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPreferences {
  final String? locationCity;
  final String? locationState;
  final bool notificationsEnabled;
  final bool floatingBubbleVisible;

  const UserPreferences({
    this.locationCity,
    this.locationState,
    this.notificationsEnabled = true,
    this.floatingBubbleVisible = true,
  });

  String? get locationLabel {
    final parts = [locationCity, locationState]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  UserPreferences copyWith({
    String? locationCity,
    String? locationState,
    bool? notificationsEnabled,
    bool? floatingBubbleVisible,
  }) {
    return UserPreferences(
      locationCity: locationCity ?? this.locationCity,
      locationState: locationState ?? this.locationState,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      floatingBubbleVisible:
          floatingBubbleVisible ?? this.floatingBubbleVisible,
    );
  }
}

class UserPreferencesService {
  UserPreferencesService._();

  static final _client = Supabase.instance.client;

  static const _prefsCityKey = 'firstvue_pref_city';
  static const _prefsStateKey = 'firstvue_pref_state';
  static const _prefsNotificationsKey = 'firstvue_pref_notifications';
  static const _prefsBubbleKey = 'firstvue_pref_floating_bubble';

  static Future<UserPreferences> fetch() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final row = await _client
            .from('user_preferences')
            .select(
              'location_city, location_state, notifications_enabled, floating_bubble_visible',
            )
            .eq('user_id', user.id)
            .maybeSingle();

        if (row != null) {
          final prefs = UserPreferences(
            locationCity: row['location_city'] as String?,
            locationState: row['location_state'] as String?,
            notificationsEnabled:
                row['notifications_enabled'] as bool? ?? true,
            floatingBubbleVisible:
                row['floating_bubble_visible'] as bool? ?? true,
          );
          await _cacheLocally(prefs);
          return prefs;
        }
      } catch (_) {}
    }

    return _fetchFromLocal();
  }

  static Future<UserPreferences> _fetchFromLocal() async {
    final sp = await SharedPreferences.getInstance();
    return UserPreferences(
      locationCity: sp.getString(_prefsCityKey),
      locationState: sp.getString(_prefsStateKey),
      notificationsEnabled: sp.getBool(_prefsNotificationsKey) ?? true,
      floatingBubbleVisible: sp.getBool(_prefsBubbleKey) ?? true,
    );
  }

  static Future<void> _cacheLocally(UserPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    if (prefs.locationCity != null) {
      await sp.setString(_prefsCityKey, prefs.locationCity!);
    }
    if (prefs.locationState != null) {
      await sp.setString(_prefsStateKey, prefs.locationState!);
    }
    await sp.setBool(_prefsNotificationsKey, prefs.notificationsEnabled);
    await sp.setBool(_prefsBubbleKey, prefs.floatingBubbleVisible);
  }

  static Future<void> updateLocation({
    String? city,
    String? state,
  }) async {
    final user = _client.auth.currentUser;
    final trimmedCity = city?.trim();
    final trimmedState = state?.trim();

    final sp = await SharedPreferences.getInstance();
    if (trimmedCity != null && trimmedCity.isNotEmpty) {
      await sp.setString(_prefsCityKey, trimmedCity);
    } else {
      await sp.remove(_prefsCityKey);
    }
    if (trimmedState != null && trimmedState.isNotEmpty) {
      await sp.setString(_prefsStateKey, trimmedState);
    } else {
      await sp.remove(_prefsStateKey);
    }

    if (user == null) return;

    try {
      await _client.from('user_preferences').upsert({
        'user_id': user.id,
        'location_city': trimmedCity,
        'location_state': trimmedState,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> updateNotificationsEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefsNotificationsKey, enabled);

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('user_preferences').upsert({
        'user_id': user.id,
        'notifications_enabled': enabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> updateFloatingBubbleVisible(bool visible) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefsBubbleKey, visible);

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('user_preferences').upsert({
        'user_id': user.id,
        'floating_bubble_visible': visible,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> restoreFloatingBubble() =>
      updateFloatingBubbleVisible(true);
}
