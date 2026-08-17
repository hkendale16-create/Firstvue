import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_profile_service.dart';

class UserPreferences {
  final String? locationCity;
  final String? locationState;
  final bool browseEverywhere;
  final bool notificationsEnabled;
  final bool floatingBubbleVisible;
  final bool pushLiveNearby;

  const UserPreferences({
    this.locationCity,
    this.locationState,
    this.browseEverywhere = false,
    this.notificationsEnabled = true,
    this.floatingBubbleVisible = true,
    this.pushLiveNearby = true,
  });

  String? get locationLabel {
    if (browseEverywhere) return 'Everywhere';
    final parts = [locationCity, locationState]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  UserPreferences copyWith({
    String? locationCity,
    String? locationState,
    bool? browseEverywhere,
    bool? notificationsEnabled,
    bool? floatingBubbleVisible,
    bool? pushLiveNearby,
  }) {
    return UserPreferences(
      locationCity: locationCity ?? this.locationCity,
      locationState: locationState ?? this.locationState,
      browseEverywhere: browseEverywhere ?? this.browseEverywhere,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      floatingBubbleVisible:
          floatingBubbleVisible ?? this.floatingBubbleVisible,
      pushLiveNearby: pushLiveNearby ?? this.pushLiveNearby,
    );
  }
}

class UserPreferencesService {
  UserPreferencesService._();

  static final _client = Supabase.instance.client;

  static const _prefsCityKey = 'firstvue_pref_city';
  static const _prefsStateKey = 'firstvue_pref_state';
  static const _prefsEverywhereKey = 'firstvue_pref_everywhere';
  static const _prefsNotificationsKey = 'firstvue_pref_notifications';
  static const _prefsBubbleKey = 'firstvue_pref_floating_bubble';
  static const _prefsLiveNearbyKey = 'firstvue_pref_push_live_nearby';

  static Future<UserPreferences> fetch() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final row = await _client
            .from('user_preferences')
            .select(
              'preferred_city, preferred_state, browse_everywhere, push_messages, show_floating_messages, push_live_nearby',
            )
            .eq('profile_id', user.id)
            .maybeSingle();

        if (row != null) {
          final prefs = UserPreferences(
            locationCity: row['preferred_city'] as String?,
            locationState: row['preferred_state'] as String?,
            browseEverywhere: row['browse_everywhere'] as bool? ?? false,
            notificationsEnabled: row['push_messages'] as bool? ?? true,
            floatingBubbleVisible:
                row['show_floating_messages'] as bool? ?? true,
            pushLiveNearby: row['push_live_nearby'] as bool? ?? true,
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
            final prefs = UserPreferences(
              locationCity: row['preferred_city'] as String?,
              locationState: row['preferred_state'] as String?,
              browseEverywhere: local.browseEverywhere,
              notificationsEnabled: row['push_messages'] as bool? ?? true,
              floatingBubbleVisible:
                  row['show_floating_messages'] as bool? ?? true,
              pushLiveNearby: local.pushLiveNearby,
            );
            await _cacheLocally(prefs);
            return prefs;
          }
        } catch (_) {}
      }

      final profile = await UserProfileService.fetchProfile();
      if (profile?.city != null || profile?.state != null) {
        final local = await _fetchFromLocal();
        final prefs = UserPreferences(
          locationCity: profile?.city,
          locationState: profile?.state,
          browseEverywhere: local.browseEverywhere,
          pushLiveNearby: local.pushLiveNearby,
        );
        await _cacheLocally(prefs);
        return prefs;
      }
    }

    return _fetchFromLocal();
  }

  /// City/metro from local prefs only — no Supabase round-trip.
  static Future<String?> localCity() async {
    final prefs = await _fetchFromLocal();
    if (prefs.browseEverywhere) return null;
    final city = prefs.locationCity?.trim();
    if (city == null || city.isEmpty) return null;
    return city;
  }

  static Future<UserPreferences> _fetchFromLocal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return UserPreferences(
        locationCity: sp.getString(_prefsCityKey),
        locationState: sp.getString(_prefsStateKey),
        browseEverywhere: sp.getBool(_prefsEverywhereKey) ?? false,
        notificationsEnabled: sp.getBool(_prefsNotificationsKey) ?? true,
        floatingBubbleVisible: sp.getBool(_prefsBubbleKey) ?? true,
        pushLiveNearby: sp.getBool(_prefsLiveNearbyKey) ?? true,
      );
    } catch (_) {
      return const UserPreferences();
    }
  }

  static Future<void> _cacheLocally(UserPreferences prefs) async {
    try {
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
      await sp.setBool(_prefsLiveNearbyKey, prefs.pushLiveNearby);
    } catch (_) {
      // Local cache is best-effort — never break Explore / nearby queries.
    }
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

  static Future<void> updatePushLiveNearby(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefsLiveNearbyKey, enabled);

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('user_preferences').upsert({
        'profile_id': user.id,
        'push_live_nearby': enabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> restoreFloatingBubble() =>
      updateFloatingBubbleVisible(true);
}
