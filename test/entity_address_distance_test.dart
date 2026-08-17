import 'package:firstvue/services/entity_distance_service.dart';
import 'package:firstvue/utils/entity_address_requirements.dart';
import 'package:firstvue/widgets/smart_address_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntityAddressRequirements', () {
    test('personal profiles never require an address', () {
      expect(
        EntityAddressRequirements.validate(
          const AddressResult(),
          kind: EntityAddressKind.personal,
        ),
        isNull,
      );
    });

    test('business requires street, city, state, and zip', () {
      expect(
        EntityAddressRequirements.validate(
          const AddressResult(street: '123 Main'),
          kind: EntityAddressKind.business,
          requireCoordinates: false,
        ),
        contains('city'),
      );
      expect(
        EntityAddressRequirements.validate(
          const AddressResult(
            street: '123 Main',
            city: 'Austin',
            state: 'TX',
            zip: '78701',
            lat: 30.2,
            lng: -97.7,
          ),
          kind: EntityAddressKind.business,
        ),
        isNull,
      );
    });

    test('community requires city and state', () {
      expect(
        EntityAddressRequirements.validateCityState(
          city: '',
          state: 'TX',
          kind: EntityAddressKind.community,
        ),
        contains('city'),
      );
      expect(
        EntityAddressRequirements.validateCityState(
          city: 'Austin',
          state: 'TX',
          kind: EntityAddressKind.community,
        ),
        isNull,
      );
    });
  });

  group('EntityDistanceService', () {
    test('estimateDriveMinutes scales with distance', () {
      expect(EntityDistanceService.estimateDriveMinutes(0), 1);
      expect(EntityDistanceService.estimateDriveMinutes(2.4), greaterThan(2));
      expect(
        EntityDistanceService.estimateDriveMinutes(2.4),
        lessThan(EntityDistanceService.estimateDriveMinutes(20)),
      );
    });

    test('haversineMiles returns zero for same point', () {
      expect(
        EntityDistanceService.haversineMiles(
          fromLat: 30.0,
          fromLng: -97.0,
          toLat: 30.0,
          toLng: -97.0,
        ),
        0,
      );
    });

    test('haversineMiles is roughly correct for nearby cities', () {
      // Austin to Houston ~145–165 miles.
      final miles = EntityDistanceService.haversineMiles(
        fromLat: 30.2672,
        fromLng: -97.7431,
        toLat: 29.7604,
        toLng: -95.3698,
      );
      expect(miles, greaterThan(140));
      expect(miles, lessThan(170));
    });

    test('compactLabel format', () {
      final result = EntityDistanceResult(
        distanceMiles: 2.4,
        driveMinutes: 8,
        computedAt: DateTime.now(),
        userLat: 30,
        userLng: -97,
      );
      expect(result.compactLabel, '2.4 miles away · ~8 min drive');
    });
  });
}
