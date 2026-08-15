import 'package:firstvue/services/event_geocode_service.dart';
import 'package:firstvue/services/live_home_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty location label does not geocode', () async {
    EventGeocodeService.clearCache();
    expect(await EventGeocodeService.resolve(null), isNull);
    expect(await EventGeocodeService.resolve('   '), isNull);
  });

  test('same-day delayed class without ends_at stays on LIVE', () {
    // Event started earlier today, no ends_at (pre-Phase-7 style).
    final now = DateTime(2026, 8, 15, 15, 0);
    final delayedClassStart = DateTime(2026, 8, 15, 9, 0);
    expect(
      LiveHomeService.lifecycleFor(delayedClassStart, now: now),
      LiveLifecycleStatus.live,
    );
  });
}
