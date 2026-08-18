import 'live_home_service.dart';
import 'things_to_do_service.dart';

/// Calendar windows for Home "Tonight / Right now" without GPS.
class EventTimeWindows {
  EventTimeWindows._();

  static LiveLifecycleStatus lifecycle(
    CommunityEvent event, {
    DateTime? now,
  }) {
    return LiveHomeService.lifecycleFor(
      event.eventAt,
      endsAt: event.endsAt,
      now: now,
    );
  }

  static bool isHappeningNow(CommunityEvent event, {DateTime? now}) {
    final status = lifecycle(event, now: now);
    return status == LiveLifecycleStatus.live ||
        status == LiveLifecycleStatus.endingSoon ||
        status == LiveLifecycleStatus.startingSoon;
  }

  static bool isEnded(CommunityEvent event, {DateTime? now}) {
    return lifecycle(event, now: now) == LiveLifecycleStatus.ended;
  }

  static DateTime localDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Friday 00:00 through Sunday of the current or upcoming weekend.
  static ({DateTime friday, DateTime sunday}) weekendBounds(DateTime now) {
    final day = localDay(now);
    final weekday = day.weekday;
    final DateTime friday;
    if (weekday >= DateTime.friday) {
      friday = day.subtract(Duration(days: weekday - DateTime.friday));
    } else {
      friday = day.add(Duration(days: DateTime.friday - weekday));
    }
    return (friday: friday, sunday: friday.add(const Duration(days: 2)));
  }

  static bool isTonight(CommunityEvent event, {DateTime? now}) {
    final at = event.eventAt;
    if (at == null) return false;
    if (isEnded(event, now: now)) return false;
    return localDay(at) == localDay(now ?? DateTime.now());
  }

  static bool isThisWeekend(CommunityEvent event, {DateTime? now}) {
    final at = event.eventAt;
    if (at == null) return false;
    if (isEnded(event, now: now)) return false;
    final bounds = weekendBounds(now ?? DateTime.now());
    final end = DateTime(
      bounds.sunday.year,
      bounds.sunday.month,
      bounds.sunday.day,
      23,
      59,
      59,
      999,
    );
    final localAt = at.toLocal();
    return !localAt.isBefore(bounds.friday) && !localAt.isAfter(end);
  }

  static List<CommunityEvent> happeningNow(
    List<CommunityEvent> events, {
    DateTime? now,
  }) {
    return [
      for (final event in events)
        if (isHappeningNow(event, now: now)) event,
    ];
  }

  static List<CommunityEvent> tonight(
    List<CommunityEvent> events, {
    DateTime? now,
  }) {
    return [
      for (final event in events)
        if (isTonight(event, now: now)) event,
    ];
  }

  static List<CommunityEvent> thisWeekend(
    List<CommunityEvent> events, {
    DateTime? now,
  }) {
    return [
      for (final event in events)
        if (isThisWeekend(event, now: now)) event,
    ];
  }
}
