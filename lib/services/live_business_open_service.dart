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
  });

  bool get isFoodTruck {
    final t = (businessType ?? '').toLowerCase();
    return t.contains('food truck') || t.contains('foodtruck');
  }

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
      subtitle: note ?? businessType,
      lifecycle: lifecycle(),
      locationLabel: note,
      businessId: businessId,
    );
  }
}

/// Operator open check-ins for Food Truck / business LIVE (Phase 8).
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

  static Future<LiveBusinessOpenSession?> activeForBusiness(
    String businessId,
  ) async {
    final all = await listActive(limit: 100);
    for (final s in all) {
      if (s.businessId == businessId) return s;
    }
    return null;
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

  static Future<void> end({required String businessId}) async {
    await _client.rpc(
      'end_business_open_session',
      params: {'p_business_id': businessId},
    );
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
    );
  }
}
