import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feature_flags.dart';

class LiveEventEngagement {
  final bool going;
  final bool hot;
  final bool hereNow;
  final int goingCount;
  final int hotCount;
  final int hereNowCount;
  final List<String> hereNowProfileIds;

  const LiveEventEngagement({
    this.going = false,
    this.hot = false,
    this.hereNow = false,
    this.goingCount = 0,
    this.hotCount = 0,
    this.hereNowCount = 0,
    this.hereNowProfileIds = const [],
  });
}

/// LIVE event Going / Hot / I'm Here. Presence is voluntary and time-limited.
class LiveEventEngagementService {
  LiveEventEngagementService._();

  static final _client = Supabase.instance.client;

  static const presenceTtl = Duration(hours: 4);

  static bool _isRealEventId(String eventId) => !eventId.startsWith('proto-');

  static Future<LiveEventEngagement> fetch(String eventId) async {
    if (!_isRealEventId(eventId)) return const LiveEventEngagement();
    final me = _client.auth.currentUser;

    var going = false;
    var hot = false;
    var hereNow = false;
    var goingCount = 0;
    var hotCount = 0;
    var hereNowCount = 0;
    var hereIds = <String>[];

    try {
      final rows = await _client
          .from('event_attendance')
          .select('profile_id, status')
          .eq('event_id', eventId)
          .eq('status', 'attending');
      goingCount = rows.length;
      if (me != null) {
        going = rows.any((r) => r['profile_id'] == me.id);
      }
    } catch (_) {}

    try {
      final rows = await _client
          .from('event_hot_reactions')
          .select('profile_id')
          .eq('event_id', eventId);
      hotCount = rows.length;
      if (me != null) {
        hot = rows.any((r) => r['profile_id'] == me.id);
      }
    } catch (_) {}

    if (FeatureFlags.liveEventPresenceEnabled) {
      try {
        final count = await _client.rpc(
          'event_here_now_count',
          params: {'p_event_id': eventId},
        );
        if (count is int) {
          hereNowCount = count;
        } else if (count is num) {
          hereNowCount = count.toInt();
        }
      } catch (_) {}

      try {
        final rows = await _client
            .from('event_presence')
            .select('profile_id, expires_at')
            .eq('event_id', eventId)
            .gt('expires_at', DateTime.now().toUtc().toIso8601String())
            .order('updated_at', ascending: false)
            .limit(12);
        hereIds = rows
            .map((r) => r['profile_id'] as String?)
            .whereType<String>()
            .toList();
        if (me != null) {
          hereNow = hereIds.contains(me.id);
        }
        if (hereNowCount == 0 && hereIds.isNotEmpty) {
          hereNowCount = hereIds.length;
        }
      } catch (_) {}
    }

    return LiveEventEngagement(
      going: going,
      hot: hot,
      hereNow: hereNow,
      goingCount: goingCount,
      hotCount: hotCount,
      hereNowCount: hereNowCount,
      hereNowProfileIds: hereIds,
    );
  }

  static Future<bool> setGoing(String eventId, {required bool going}) async {
    if (!_isRealEventId(eventId)) return going;
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to RSVP.');

    if (going) {
      await _client.from('event_attendance').upsert({
        'event_id': eventId,
        'profile_id': me.id,
        'status': 'attending',
      });
      return true;
    }
    await _client
        .from('event_attendance')
        .delete()
        .eq('event_id', eventId)
        .eq('profile_id', me.id);
    return false;
  }

  static Future<bool> setHot(String eventId, {required bool hot}) async {
    if (!_isRealEventId(eventId)) return hot;
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to react.');

    if (hot) {
      try {
        await _client.from('event_hot_reactions').insert({
          'event_id': eventId,
          'profile_id': me.id,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
      return true;
    }
    await _client
        .from('event_hot_reactions')
        .delete()
        .eq('event_id', eventId)
        .eq('profile_id', me.id);
    return false;
  }

  /// Voluntary presence only — no GPS stored or broadcast.
  static Future<bool> setHereNow(String eventId, {required bool here}) async {
    if (!_isRealEventId(eventId)) return here;
    if (!FeatureFlags.liveEventPresenceEnabled) {
      throw StateError('LIVE event presence is disabled.');
    }
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to check in.');

    if (here) {
      await _client.rpc(
        'set_event_presence',
        params: {'p_event_id': eventId},
      );
      return true;
    }
    await _client.rpc(
      'clear_event_presence',
      params: {'p_event_id': eventId},
    );
    return false;
  }

  /// Pure helper for tests: presence is active only before expires_at.
  static bool isPresenceActive(DateTime expiresAt, {DateTime? now}) {
    final n = now ?? DateTime.now().toUtc();
    return expiresAt.toUtc().isAfter(n);
  }
}
