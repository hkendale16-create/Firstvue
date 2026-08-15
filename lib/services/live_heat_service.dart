import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';

enum LiveHeatStatus { active, heatingUp, hot }

class LiveHeatScore {
  final String eventId;
  final double score;
  final LiveHeatStatus? status;
  final int goingRecent;
  final int hereNow;
  final int hotRecent;
  final int vueRecent;

  const LiveHeatScore({
    required this.eventId,
    required this.score,
    required this.status,
    this.goingRecent = 0,
    this.hereNow = 0,
    this.hotRecent = 0,
    this.vueRecent = 0,
  });

  String? get badgeLabel => switch (status) {
        LiveHeatStatus.hot => '🔥 HOT',
        LiveHeatStatus.heatingUp => 'Heating Up',
        LiveHeatStatus.active => 'Active',
        null => null,
      };
}

class LiveHeatService {
  LiveHeatService._();

  static final _client = Supabase.instance.client;

  /// Pure threshold helper for tests / offline fallback.
  static LiveHeatStatus? statusForScore({
    required double score,
    required int signalCount,
    required int hereNow,
    required int vueRecent,
  }) {
    if (score >= 20 && (hereNow >= 2 || vueRecent >= 2)) {
      return LiveHeatStatus.hot;
    }
    if (score >= 8 && signalCount >= 3) return LiveHeatStatus.heatingUp;
    if (score >= 3) return LiveHeatStatus.active;
    return null;
  }

  static Future<Map<String, LiveHeatScore>> fetchForEvents(
    List<String> eventIds,
  ) async {
    if (!FeatureFlags.liveHeatActivityEnabled) return const {};
    final ids = eventIds
        .where((id) => id.isNotEmpty && !id.startsWith('proto-'))
        .toSet()
        .take(100)
        .toList();
    if (ids.isEmpty) return const {};

    try {
      final rows = await _client.rpc(
        'live_event_heat_scores',
        params: {'p_event_ids': ids},
      );
      final out = <String, LiveHeatScore>{};
      if (rows is! List) return out;
      for (final row in rows) {
        if (row is! Map) continue;
        final id = row['event_id'] as String?;
        if (id == null) continue;
        final statusRaw = row['status'] as String?;
        final status = switch (statusRaw) {
          'hot' => LiveHeatStatus.hot,
          'heating_up' => LiveHeatStatus.heatingUp,
          'active' => LiveHeatStatus.active,
          _ => null,
        };
        out[id] = LiveHeatScore(
          eventId: id,
          score: (row['score'] as num?)?.toDouble() ?? 0,
          status: status,
          goingRecent: (row['going_recent'] as num?)?.toInt() ?? 0,
          hereNow: (row['here_now'] as num?)?.toInt() ?? 0,
          hotRecent: (row['hot_recent'] as num?)?.toInt() ?? 0,
          vueRecent: (row['vue_recent'] as num?)?.toInt() ?? 0,
        );
      }
      return out;
    } catch (_) {
      return const {};
    }
  }
}
