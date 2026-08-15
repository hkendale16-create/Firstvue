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

  LiveEventEngagement copyWith({
    bool? going,
    bool? hot,
    bool? hereNow,
    int? goingCount,
    int? hotCount,
    int? hereNowCount,
    List<String>? hereNowProfileIds,
  }) {
    return LiveEventEngagement(
      going: going ?? this.going,
      hot: hot ?? this.hot,
      hereNow: hereNow ?? this.hereNow,
      goingCount: goingCount ?? this.goingCount,
      hotCount: hotCount ?? this.hotCount,
      hereNowCount: hereNowCount ?? this.hereNowCount,
      hereNowProfileIds: hereNowProfileIds ?? this.hereNowProfileIds,
    );
  }
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

    final goingFuture = () async {
      var going = false;
      var goingCount = 0;
      try {
        final rows = await _client
            .from('event_attendance')
            .select('profile_id')
            .eq('event_id', eventId)
            .eq('status', 'attending');
        goingCount = rows.length;
        if (me != null) {
          going = rows.any((r) => r['profile_id'] == me.id);
        }
      } catch (_) {}
      return (going, goingCount);
    }();

    final hotFuture = () async {
      var hot = false;
      var hotCount = 0;
      try {
        // Prefer count RPC (does not expose other profile ids).
        try {
          final count = await _client.rpc(
            'event_hot_count',
            params: {'p_event_id': eventId},
          );
          if (count is int) {
            hotCount = count;
          } else if (count is num) {
            hotCount = count.toInt();
          }
        } catch (_) {
          final rows = await _client
              .from('event_hot_reactions')
              .select('profile_id')
              .eq('event_id', eventId);
          hotCount = rows.length;
        }
        if (me != null) {
          final mine = await _client
              .from('event_hot_reactions')
              .select('profile_id')
              .eq('event_id', eventId)
              .eq('profile_id', me.id)
              .maybeSingle();
          hot = mine != null;
        }
      } catch (_) {}
      return (hot, hotCount);
    }();

    final presenceFuture = () async {
      var hereNow = false;
      var hereNowCount = 0;
      if (!FeatureFlags.liveEventPresenceEnabled) {
        return (hereNow, hereNowCount);
      }
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
      if (me != null) {
        try {
          final mine = await _client
              .from('event_presence')
              .select('profile_id')
              .eq('event_id', eventId)
              .eq('profile_id', me.id)
              .gt('expires_at', DateTime.now().toUtc().toIso8601String())
              .maybeSingle();
          hereNow = mine != null;
        } catch (_) {}
      }
      return (hereNow, hereNowCount);
    }();

    final results = await Future.wait<(bool, int)>([
      goingFuture,
      hotFuture,
      presenceFuture,
    ]);
    final going = results[0];
    final hot = results[1];
    final presence = results[2];

    return LiveEventEngagement(
      going: going.$1,
      hot: hot.$1,
      hereNow: presence.$1,
      goingCount: going.$2,
      hotCount: hot.$2,
      hereNowCount: presence.$2,
      // Do not broadcast other members' profile ids from presence.
      hereNowProfileIds: presence.$1 && me != null ? [me.id] : const [],
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
