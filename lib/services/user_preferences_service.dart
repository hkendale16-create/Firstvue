import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserPreferences {
  final String? locationCity;
  final String? locationState;
  final bool browseEverywhere;
  final bool notificationsEnabled;
  final bool floatingBubbleVisible;

  const UserPreferences({
    this.locationCity,
    this.locationState,
    this.browseEverywhere = false,
    this.notificationsEnabled = true,
    this.floatingBubbleVisible = true,
  });

  String? get locationLabel {
    if (browseEverywhere) return 'Everywhere';
    final parts = [
      locationCity,
      locationState,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  UserPreferences copyWith({
    String? locationCity,
    String? locationState,
    bool? browseEverywhere,
    bool? notificationsEnabled,
    bool? floatingBubbleVisible,
  }) {
    return UserPreferences(
      locationCity: locationCity ?? this.locationCity,
      locationState: locationState ?? this.locationState,
      browseEverywhere: browseEverywhere ?? this.browseEverywhere,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      floatingBubbleVisible:
          floatingBubbleVisible ?? this.floatingBubbleVisible,
    );
  }
}

class UserPreferencesService {
  UserPreferencesService._();

  static final _client = Supabase.instance.client;

  /// Discovery location comes from the city chip / `user_preferences` row.
  ///
  /// Do not merge a profile address into discovery prefs — that made signed-in
  /// users see a thinner catalog than guests.
  static UserPreferences discoveryPreferences({
    UserPreferences? savedRow,
    required UserPreferences local,
  }) {
    return savedRow ?? local;
  }

  static const _prefsCityKey = 'firstvue_pref_city';
  static const _prefsStateKey = 'firstvue_pref_state';
  static const _prefsEverywhereKey = 'firstvue_pref_everywhere';
  static const _prefsNotificationsKey = 'firstvue_pref_notifications';
  static const _prefsBubbleKey = 'firstvue_pref_floating_bubble';

  static Future<UserPreferences> fetch() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final row = await _client
            .from('user_preferences')
            .select(
              'preferred_city, preferred_state, browse_everywhere, push_messages, show_floating_messages',
            )
            .eq('profile_id', user.id)
            .maybeSingle();

        if (row != null) {
          final prefs = discoveryPreferences(
            savedRow: UserPreferences(
              locationCity: row['preferred_city'] as String?,
              locationState: row['preferred_state'] as String?,
              browseEverywhere: row['browse_everywhere'] as bool? ?? false,
              notificationsEnabled: row['push_messages'] as bool? ?? true,
              floatingBubbleVisible:
                  row['show_floating_messages'] as bool? ?? true,
            ),
            local: await _fetchFromLocal(),
          );
          await _cacheLocally(prefs);
          return prefs;
        }
      } catch (_) {
        try {
          final row = await _client
              .from('user_preferences')
              .select(
                'preferred_city, preferred_state, push_messages, show_floating_messages',
              )
              .eq('profile_id', user.id)
              .maybeSingle();

          if (row != null) {
            final local = await _fetchFromLocal();
            final prefs = discoveryPreferences(
              savedRow: UserPreferences(
                locationCity: row['preferred_city'] as String?,
                locationState: row['preferred_state'] as String?,
                browseEverywhere: local.browseEverywhere,
                notificationsEnabled: row['push_messages'] as bool? ?? true,
                floatingBubbleVisible:
                    row['show_floating_messages'] as bool? ?? true,
              ),
              local: local,
            );
            await _cacheLocally(prefs);
            return prefs;
          }
        } catch (_) {}
      }

      // Profile city/state are identity, not a discovery lock. Copying them
      // here hid the public Home/VUE catalog for every signed-in user who
      // filled an address, while guests still saw every city.
    }

    return _fetchFromLocal();
  }

  static Future<UserPreferences> _fetchFromLocal() async {
    final sp = await SharedPreferences.getInstance();
    return UserPreferences(
      locationCity: sp.getString(_prefsCityKey),
      locationState: sp.getString(_prefsStateKey),
      browseEverywhere: sp.getBool(_prefsEverywhereKey) ?? false,
      notificationsEnabled: sp.getBool(_prefsNotificationsKey) ?? true,
      floatingBubbleVisible: sp.getBool(_prefsBubbleKey) ?? true,
    );
  }

  static Future<void> _cacheLocally(UserPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    if (prefs.locationCity != null) {
      await sp.setString(_prefsCityKey, prefs.locationCity!);
    } else {
      await sp.remove(_prefsCityKey);
    }
    if (prefs.locationState != null) {
      await sp.setString(_prefsStateKey, prefs.locationState!);
    } else {
      await sp.remove(_prefsStateKey);
    }
    await sp.setBool(_prefsEverywhereKey, prefs.browseEverywhere);
    await sp.setBool(_prefsNotificationsKey, prefs.notificationsEnabled);
    await sp.setBool(_prefsBubbleKey, prefs.floatingBubbleVisible);
  }

  static Future<void> updateLocation({
    String? city,
    String? state,
    bool? browseEverywhere,
  }) async {
    final user = _client.auth.currentUser;
    final trimmedCity = city?.trim();
    final trimmedState = state?.trim();
    final everywhere = browseEverywhere ?? false;

    final sp = await SharedPreferences.getInstance();
    if (everywhere) {
      await sp.remove(_prefsCityKey);
      await sp.remove(_prefsStateKey);
      await sp.setBool(_prefsEverywhereKey, true);
    } else {
      await sp.setBool(_prefsEverywhereKey, false);
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
    }

    if (user == null) return;

    try {
      await _client.from('user_preferences').upsert({
        'profile_id': user.id,
        'preferred_city': everywhere ? null : trimmedCity,
        'preferred_state': everywhere ? null : trimmedState,
        'browse_everywhere': everywhere,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      try {
        await _client.from('user_preferences').upsert({
          'profile_id': user.id,
          'preferred_city': everywhere ? null : trimmedCity,
          'preferred_state': everywhere ? null : trimmedState,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
    }
  }

  static Future<void> updateNotificationsEnabled(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefsNotificationsKey, enabled);

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('user_preferences').upsert({
        'profile_id': user.id,
        'push_messages': enabled,
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
        'profile_id': user.id,
        'show_floating_messages': visible,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> restoreFloatingBubble() =>
      updateFloatingBubbleVisible(true);
}
