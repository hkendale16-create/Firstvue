import 'package:firstvue/services/event_time_windows.dart';
import 'package:firstvue/services/live_home_service.dart';
import 'package:firstvue/services/things_to_do_service.dart';
import 'package:firstvue/services/user_preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityEvent _event({
  required String id,
  required DateTime eventAt,
  DateTime? endsAt,
}) {
  return CommunityEvent(
    id: id,
    title: id,
    description: 'Local event',
    eventAt: eventAt,
    locationLabel: 'Atlanta',
    businessName: 'Host',
    endsAt: endsAt,
    status: 'approved',
  );
}

void main() {
  final now = DateTime(2026, 1, 3, 18); // Saturday evening

  test('weekend bounds use the current Fri–Sun when already weekend', () {
    final bounds = EventTimeWindows.weekendBounds(now);
    expect(bounds.friday, DateTime(2026, 1, 2));
    expect(bounds.sunday, DateTime(2026, 1, 4));
  });

  test('weekend bounds look ahead to Friday mid-week', () {
    final bounds = EventTimeWindows.weekendBounds(DateTime(2025, 12, 31, 10));
    expect(bounds.friday, DateTime(2026, 1, 2));
    expect(bounds.sunday, DateTime(2026, 1, 4));
  });

  test('tonight is the local calendar day and still in progress', () {
    final tonight = _event(
      id: 'tonight',
      eventAt: DateTime(2026, 1, 3, 21),
    );
    final tomorrow = _event(
      id: 'tomorrow',
      eventAt: DateTime(2026, 1, 4, 21),
    );
    expect(EventTimeWindows.isTonight(tonight, now: now), isTrue);
    expect(EventTimeWindows.isTonight(tomorrow, now: now), isFalse);
  });

  test('this weekend includes Friday through Sunday', () {
    final midweek = DateTime(2025, 12, 31, 10); // Wednesday
    final friday = _event(id: 'fri', eventAt: DateTime(2026, 1, 2, 19));
    final sunday = _event(id: 'sun', eventAt: DateTime(2026, 1, 4, 14));
    final monday = _event(id: 'mon', eventAt: DateTime(2026, 1, 5, 19));
    expect(EventTimeWindows.isThisWeekend(friday, now: midweek), isTrue);
    expect(EventTimeWindows.isThisWeekend(sunday, now: midweek), isTrue);
    expect(EventTimeWindows.isThisWeekend(monday, now: midweek), isFalse);
  });

  test('happening now uses LIVE lifecycle including starting soon', () {
    final live = _event(
      id: 'live',
      eventAt: now.subtract(const Duration(hours: 1)),
    );
    final soon = _event(
      id: 'soon',
      eventAt: now.add(const Duration(minutes: 20)),
    );
    final later = _event(
      id: 'later',
      eventAt: now.add(const Duration(hours: 5)),
    );
    expect(EventTimeWindows.isHappeningNow(live, now: now), isTrue);
    expect(EventTimeWindows.isHappeningNow(soon, now: now), isTrue);
    expect(EventTimeWindows.isHappeningNow(later, now: now), isFalse);
    expect(
      EventTimeWindows.lifecycle(live, now: now),
      LiveLifecycleStatus.live,
    );
  });

  test('ended events drop out of tonight', () {
    final ended = _event(
      id: 'ended',
      eventAt: now.subtract(const Duration(hours: 6)),
      endsAt: now.subtract(const Duration(hours: 1)),
    );
    expect(EventTimeWindows.isTonight(ended, now: now), isFalse);
    expect(EventTimeWindows.isHappeningNow(ended, now: now), isFalse);
  });

  test('needsCityPrompt is true until a city or Everywhere is set', () {
    expect(const UserPreferences().needsCityPrompt, isTrue);
    expect(
      const UserPreferences(locationState: 'Georgia').needsCityPrompt,
      isTrue,
    );
    expect(
      const UserPreferences(locationCity: 'Atlanta').needsCityPrompt,
      isFalse,
    );
    expect(
      const UserPreferences(browseEverywhere: true).needsCityPrompt,
      isFalse,
    );
  });
}
