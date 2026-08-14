import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/services/rentals_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public rental location uses city/state, not a private street', () {
    final listing = RentalListing.fromMap({
      'id': 'r1',
      'owner_id': 'u1',
      'title': 'Midtown loft',
      'city': 'Atlanta',
      'state': 'GA',
      'postal_code': '30308',
      'description': 'Bright loft',
      'status': 'approved',
      'weekly_price_cents': null,
      'monthly_price_cents': 180000,
    });
    expect(listing.location, 'Atlanta, GA, 30308');
    expect(listing.location.contains('Peachtree'), isFalse);
  });

  test('live streaming stays behind a feature flag', () {
    expect(FeatureFlags.liveStreamingEnabled, isFalse);
  });
}
