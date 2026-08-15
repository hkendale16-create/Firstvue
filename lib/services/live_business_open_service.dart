import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';
import 'live_home_service.dart';

class LiveBusinessOpenSession {
  final String sessionId;
  final String businessId;
  final String businessName;
  final String? businessType;
  final String? note;
  final double? latitude;
  final double? longitude;
  final DateTime startedAt;
  final DateTime endsAt;
  final String? locationType;
  final String? placeLabel;
  final String? addressText;
  final String? status;
  final double? distanceMiles;

  const LiveBusinessOpenSession({
    required this.sessionId,
    required this.businessId,
    required this.businessName,
    this.businessType,
    this.note,
    this.latitude,
    this.longitude,
    required this.startedAt,
    required this.endsAt,
    this.locationType,
    this.placeLabel,
    this.addressText,
    this.status,
    this.distanceMiles,
  });

  bool get isActive {
    final s = (status ?? 'active').toLowerCase();
    return s == 'active' && endsAt.isAfter(DateTime.now());
  }

  bool get isFoodTruck {
    final type = (locationType ?? '').toLowerCase();
    if (type == 'food_truck') return true;
    final t = (businessType ?? '').toLowerCase();
    return t.contains('food truck') || t.contains('foodtruck');
  }

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite;

  LiveLifecycleStatus lifecycle({DateTime? now}) {
    final n = now ?? DateTime.now();
    if (!endsAt.isAfter(n)) return LiveLifecycleStatus.ended;
    final minutesToEnd = endsAt.difference(n).inMinutes;
    if (minutesToEnd <= 60) return LiveLifecycleStatus.endingSoon;
    return LiveLifecycleStatus.live;
  }

  LiveRightNowItem toRightNowItem() {
    return LiveRightNowItem(
      id: 'open:$sessionId',
      kind: LiveRightNowKind.business,
      title: businessName,
      subtitle: note ?? placeLabel ?? businessType,
      lifecycle: lifecycle(),
      locationLabel: placeLabel ?? note,
      businessId: businessId,
    );
  }
}

/// Operator open check-ins for Food Truck / business LIVE (Phase 8+).
class LiveBusinessOpenService {
  LiveBusinessOpenService._();

  static final _client = Supabase.instance.client;

  static Future<List<LiveBusinessOpenSession>> listActive({
    int limit = 40,
  }) async {
    if (!FeatureFlags.liveFoodTrucksEnabled) return const [];
    try {
      final rows = await _client.rpc(
        'list_active_business_open_sessions',
        params: {'p_limit': limit},
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(_mapRow)
          .whereType<LiveBusinessOpenSession>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<LiveBusinessOpenSession>> listNearby({
    required double latitude,
    required double longitude,
    double radiusMiles = 15,
    String? locationType,
    int limit = 40,
  }) async {
    if (!FeatureFlags.liveFoodTrucksEnabled) return const [];
    try {
      final rows = await _client.rpc(
        'list_nearby_live_locations',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_radius_miles': radiusMiles,
          'p_location_type': locationType,
          'p_limit': limit,
        },
      );
      if (rows is! List) return const [];
      return rows
          .whereType<Map>()
          .map(_mapRow)
          .whereType<LiveBusinessOpenSession>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<LiveBusinessOpenSession?> activeForBusiness(
    String businessId,
  ) async {
    if (!FeatureFlags.liveFoodTrucksEnabled) return null;
    if (businessId.trim().isEmpty) return null;
    try {
      final row = await _client
          .from('business_open_sessions')
          .select(
            'id, business_id, note, latitude, longitude, started_at, ends_at, '
            'location_type, status, place_label, address_text, '
            'businesses!inner(name, business_type)',
          )
          .eq('business_id', businessId)
          .eq('status', 'active')
          .gt('ends_at', DateTime.now().toUtc().toIso8601String())
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final business = row['businesses'];
      final name = business is Map ? business['name'] as String? : null;
      final type = business is Map ? business['business_type'] as String? : null;
      return _mapRow({
        ...Map<String, dynamic>.from(row),
        'session_id': row['id'],
        'business_name': name ?? 'Open now',
        'business_type': type,
      });
    } catch (_) {
      // Fallback: RPC list then filter (older schemas / RLS edge cases).
      final all = await listActive(limit: 40);
      for (final s in all) {
        if (s.businessId == businessId) return s;
      }
      return null;
    }
  }

  /// Active open sessions whose coordinates fall inside a map viewport.
  static Future<List<LiveBusinessOpenSession>> listActiveInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 40,
  }) async {
    if (!FeatureFlags.liveFoodTrucksEnabled) return const [];
    try {
      final rows = await _client
          .from('business_open_sessions')
          .select(
            'id, business_id, note, latitude, longitude, started_at, ends_at, '
            'location_type, status, place_label, address_text, '
            'businesses!inner(name, business_type)',
          )
          .eq('status', 'active')
          .gt('ends_at', DateTime.now().toUtc().toIso8601String())
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .gte('latitude', minLat)
          .lte('latitude', maxLat)
          .gte('longitude', minLng)
          .lte('longitude', maxLng)
          .order('started_at', ascending: false)
          .limit(limit);
      final out = <LiveBusinessOpenSession>[];
      for (final row in rows) {
        final business = row['businesses'];
        final name = business is Map ? business['name'] as String? : null;
        final type =
            business is Map ? business['business_type'] as String? : null;
        final mapped = _mapRow({
          ...Map<String, dynamic>.from(row as Map),
          'session_id': row['id'],
          'business_name': name ?? 'Open now',
          'business_type': type,
        });
        if (mapped != null) out.add(mapped);
      }
      return out;
    } catch (_) {
      final all = await listActive(limit: limit * 2);
      return all.where((s) {
        final lat = s.latitude;
        final lng = s.longitude;
        if (lat == null || lng == null) return false;
        return lat >= minLat &&
            lat <= maxLat &&
            lng >= minLng &&
            lng <= maxLng;
      }).take(limit).toList();
    }
  }

  static Future<LiveBusinessOpenSession> start({
    required String businessId,
    double hours = 4,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final row = await _client.rpc(
      'start_business_open_session',
      params: {
        'p_business_id': businessId,
        'p_hours': hours,
        'p_note': note,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    return _mapStartedRow(row, businessId);
  }

  /// Preferred Go Live path — supports place label / address text.
  static Future<LiveBusinessOpenSession> startLive({
    required String businessId,
    double hours = 4,
    String? note,
    double? latitude,
    double? longitude,
    String? placeLabel,
    String? addressText,
    String? locationType,
    String? eventId,
  }) async {
    final row = await _client.rpc(
      'start_business_live_location',
      params: {
        'p_business_id': businessId,
        'p_hours': hours,
        'p_note': note,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_place_label': placeLabel,
        'p_address_text': addressText,
        'p_event_id': eventId,
        'p_location_type': locationType,
      },
    );
    return _mapStartedRow(row, businessId);
  }

  static Future<LiveBusinessOpenSession> extend({
    required String businessId,
    double additionalHours = 1,
  }) async {
    final row = await _client.rpc(
      'extend_business_open_session',
      params: {
        'p_business_id': businessId,
        'p_additional_hours': additionalHours,
      },
    );
    return _mapStartedRow(row, businessId);
  }

  static Future<void> end({required String businessId}) async {
    await _client.rpc(
      'end_business_open_session',
      params: {'p_business_id': businessId},
    );
  }

  static Future<LiveBusinessOpenSession> _mapStartedRow(
    dynamic row,
    String businessId,
  ) async {
    if (row is Map) {
      final mapped = _mapRow({
        ...Map<String, dynamic>.from(row),
        'session_id': row['id'] ?? row['session_id'],
        'business_name': row['business_name'] ?? 'Open now',
        'business_type': row['business_type'],
      });
      if (mapped != null) return mapped;
    }
    final refreshed = await activeForBusiness(businessId);
    if (refreshed != null) return refreshed;
    throw StateError('Could not start open session.');
  }

  static LiveBusinessOpenSession? _mapRow(Map row) {
    final sessionId = (row['session_id'] ?? row['id']) as String?;
    final businessId = row['business_id'] as String?;
    final name = row['business_name'] as String?;
    final started = row['started_at'] == null
        ? null
        : DateTime.tryParse(row['started_at'] as String);
    final ends = row['ends_at'] == null
        ? null
        : DateTime.tryParse(row['ends_at'] as String);
    if (sessionId == null ||
        businessId == null ||
        name == null ||
        started == null ||
        ends == null) {
      return null;
    }
    return LiveBusinessOpenSession(
      sessionId: sessionId,
      businessId: businessId,
      businessName: name,
      businessType: row['business_type'] as String?,
      note: row['note'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      startedAt: started,
      endsAt: ends,
      locationType: row['location_type'] as String?,
      placeLabel: row['place_label'] as String?,
      addressText: row['address_text'] as String?,
      status: row['status'] as String?,
      distanceMiles: (row['distance_miles'] as num?)?.toDouble(),
    );
  }
}
