import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_environment.dart';

/// Debounced LIVE realtime refresh for home / detail / map.
class LiveRealtimeService {
  LiveRealtimeService._();

  static RealtimeChannel? _homeChannel;
  static Timer? _homeDebounce;

  /// Subscribe to open-session changes. [onChange] is debounced (~700ms).
  static void subscribeHome({required void Function() onChange}) {
    if (isWidgetTestBinding) return;
    unsubscribeHome();
    _homeChannel = Supabase.instance.client
        .channel('live-home-open-sessions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'business_open_sessions',
          callback: (_) {
            _homeDebounce?.cancel();
            _homeDebounce = Timer(const Duration(milliseconds: 700), onChange);
          },
        )
        .subscribe();
  }

  static void unsubscribeHome() {
    _homeDebounce?.cancel();
    _homeDebounce = null;
    _homeChannel?.unsubscribe();
    _homeChannel = null;
  }

  static RealtimeChannel? subscribeEventEngagement({
    required String eventId,
    required void Function() onChange,
  }) {
    if (isWidgetTestBinding) return null;
    Timer? debounce;
    return Supabase.instance.client
        .channel('live-event-engagement-$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_presence',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 500), onChange);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_hot_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (_) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 500), onChange);
          },
        )
        .subscribe();
  }
}
