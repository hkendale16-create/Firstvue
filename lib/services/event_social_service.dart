import 'package:supabase_flutter/supabase_flutter.dart';

enum EventAttendanceStatus { attending, interested, notAttending }

class EventSocialState {
  final bool following;
  final EventAttendanceStatus? attendance;

  const EventSocialState({
    this.following = false,
    this.attendance,
  });
}

class EventSocialService {
  EventSocialService._();

  static final _client = Supabase.instance.client;

  static bool _isRealEventId(String eventId) {
    return !eventId.startsWith('proto-');
  }

  static Future<EventSocialState> fetchState(String eventId) async {
    if (!_isRealEventId(eventId)) return const EventSocialState();
    final me = _client.auth.currentUser;
    if (me == null) return const EventSocialState();

    var following = false;
    EventAttendanceStatus? attendance;

    try {
      final followRow = await _client
          .from('event_follows')
          .select('event_id')
          .eq('event_id', eventId)
          .eq('profile_id', me.id)
          .maybeSingle();
      following = followRow != null;
    } catch (_) {}

    try {
      final attendRow = await _client
          .from('event_attendance')
          .select('status')
          .eq('event_id', eventId)
          .eq('profile_id', me.id)
          .maybeSingle();
      final status = attendRow?['status'] as String?;
      attendance = switch (status) {
        'attending' => EventAttendanceStatus.attending,
        'interested' => EventAttendanceStatus.interested,
        'not_attending' => EventAttendanceStatus.notAttending,
        _ => null,
      };
    } catch (_) {}

    return EventSocialState(following: following, attendance: attendance);
  }

  static Future<bool> toggleFollow(String eventId, {required bool following}) async {
    if (!_isRealEventId(eventId)) return following;
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to follow events.');

    if (following) {
      try {
        await _client.from('event_follows').insert({
          'event_id': eventId,
          'profile_id': me.id,
        });
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
      }
      return true;
    }

    await _client
        .from('event_follows')
        .delete()
        .eq('event_id', eventId)
        .eq('profile_id', me.id);
    return false;
  }

  static Future<EventAttendanceStatus?> setAttendance(
    String eventId,
    EventAttendanceStatus status,
  ) async {
    if (!_isRealEventId(eventId)) return status;
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to RSVP to events.');

    final dbStatus = switch (status) {
      EventAttendanceStatus.attending => 'attending',
      EventAttendanceStatus.interested => 'interested',
      EventAttendanceStatus.notAttending => 'not_attending',
    };

    await _client.from('event_attendance').upsert({
      'event_id': eventId,
      'profile_id': me.id,
      'status': dbStatus,
    });

    return status;
  }

  static Future<void> clearAttendance(String eventId) async {
    if (!_isRealEventId(eventId)) return;
    final me = _client.auth.currentUser;
    if (me == null) return;

    await _client
        .from('event_attendance')
        .delete()
        .eq('event_id', eventId)
        .eq('profile_id', me.id);
  }
}
