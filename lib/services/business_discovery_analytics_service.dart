import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessDiscoveryAnalyticsService {
  BusinessDiscoveryAnalyticsService._();

  static final _client = Supabase.instance.client;

  static const allowedEvents = <String>{
    'food_truck_profile_viewed',
    'food_truck_live_viewed',
    'food_truck_menu_viewed',
    'food_truck_directions_tapped',
    'food_truck_followed',
    'food_truck_shared',
    'live_location_started',
    'live_location_extended',
    'live_location_ended',
    'scheduled_stop_viewed',
    'vue_opened_from_food_truck',
    'event_opened_from_food_truck',
  };

  static Future<void> recordEvent({
    required String eventName,
    required String businessId,
    String? sessionId,
    String? stopId,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    if (!allowedEvents.contains(eventName)) return;
    try {
      await _client.from('business_discovery_events').insert({
        'business_id': businessId,
        'profile_id': uid,
        'event_name': eventName,
        if (sessionId != null) 'session_id': sessionId,
        if (stopId != null) 'stop_id': stopId,
        'metadata': metadata ?? const <String, dynamic>{},
      });
    } catch (_) {
      // Analytics must never break UX.
    }
  }

  /// Owner dashboard counts for today (RPC excludes demo businesses).
  static Future<Map<String, int>> fetchTodayStats(String businessId) async {
    try {
      final row = await _client.rpc(
        'fv_business_discovery_stats_today',
        params: {'p_business_id': businessId},
      );
      if (row is! Map) return const {};
      final out = <String, int>{};
      row.forEach((key, value) {
        if (key is String && value is num) {
          out[key] = value.toInt();
        }
      });
      return out;
    } catch (_) {
      return const {};
    }
  }
}
