import 'dart:io';

import 'package:firstvue/data/industry_catalog.dart';
import 'package:firstvue/models/explore_section.dart';
import 'package:firstvue/services/live_business_open_service.dart';
import 'package:firstvue/utils/explore_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('food trucks live locations migration is present', () {
    final file = File(
      'supabase/migrations/20261011_entity_live_locations_food_trucks.sql',
    );
    expect(file.existsSync(), isTrue);
    final sql = file.readAsStringSync();
    expect(sql.contains("slug) values ('Food Truck', 'food-truck'") ||
            sql.contains("'food-truck'"), isTrue);
    expect(sql.contains('start_business_live_location'), isTrue);
    expect(sql.contains('list_nearby_live_locations'), isTrue);
    expect(sql.contains('extend_business_open_session'), isTrue);
    expect(sql.contains('business_scheduled_stops'), isTrue);
    expect(sql.contains('founding_food_truck'), isTrue);
    expect(sql.contains('push_live_nearby'), isTrue);
    // No ordering / customer payments in this migration.
    expect(
      RegExp(r'\b(checkout|stripe_checkout|payment_intent)\b', caseSensitive: false)
          .hasMatch(sql),
      isFalse,
    );
    expect(sql.toLowerCase().contains('stripe'), isFalse);
  });

  test('feature flag for food trucks defaults on', () {
    // Imported via migration presence + client services.
    expect(File('lib/config/feature_flags.dart').readAsStringSync(),
        contains('FIRSTVUE_LIVE_FOOD_TRUCKS'));
  });

  test('isFoodTruck checks locationType and businessType', () {
    final now = DateTime(2026, 8, 15, 12);
    final byType = LiveBusinessOpenSession(
      sessionId: 's1',
      businessId: 'b1',
      businessName: 'Taco Truck',
      businessType: 'Food Truck',
      startedAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
    );
    expect(byType.isFoodTruck, isTrue);

    final byLocationType = LiveBusinessOpenSession(
      sessionId: 's2',
      businessId: 'b2',
      businessName: 'Mobile Eats',
      businessType: 'Restaurant',
      locationType: 'food_truck',
      startedAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
    );
    expect(byLocationType.isFoodTruck, isTrue);

    final cafe = LiveBusinessOpenSession(
      sessionId: 's3',
      businessId: 'b3',
      businessName: 'Cafe',
      businessType: 'Cafe',
      locationType: 'mobile_business',
      startedAt: now.subtract(const Duration(hours: 1)),
      endsAt: now.add(const Duration(hours: 2)),
    );
    expect(cafe.isFoodTruck, isFalse);
  });

  test('industry catalog maps food truck before generic food', () {
    final def = IndustryCatalog.fromDisplayType('Atlanta Food Truck');
    expect(def.slug, 'food-truck');
    expect(def.template, IndustryTemplate.food);
    expect(def.parentSlug, 'food-dining');
    expect(IndustryCatalog.bySlug('food-truck').name, 'Food Truck');
    expect(
      IndustryCatalog.fromDisplayType('Restaurant').slug,
      'restaurant',
    );
  });

  test('explore section Food Trucks is labeled and visible after Food', () {
    expect(ExploreSection.foodTrucks.label, 'Food Trucks');
    final visible = ExploreSectionX.visible;
    final foodIdx = visible.indexOf(ExploreSection.food);
    final trucksIdx = visible.indexOf(ExploreSection.foodTrucks);
    expect(foodIdx, greaterThanOrEqualTo(0));
    expect(trucksIdx, foodIdx + 1);
  });

  test('food trucks are not classified only as food', () {
    final sections = ExploreClassifier.sectionsFor(
      const ExploreClassificationInput(
        authorProfileType: 'business',
        businessType: 'Food Truck',
        industrySlug: 'food-truck',
        hasBusinessId: true,
      ),
    );
    expect(sections.contains(ExploreSection.foodTrucks), isTrue);
    expect(sections.contains(ExploreSection.food), isFalse);
  });

  test('food truck screens have no checkout or payment code', () {
    final paths = [
      'lib/screens/food_trucks_discovery_screen.dart',
      'lib/widgets/live/live_food_truck_pin_sheet.dart',
      'lib/widgets/live/live_business_open_controls.dart',
      'lib/services/food_truck_discovery_service.dart',
    ];
    for (final path in paths) {
      final source = File(path).readAsStringSync().toLowerCase();
      expect(source.contains('checkout'), isFalse, reason: path);
      expect(source.contains('stripe'), isFalse, reason: path);
      expect(source.contains('paymentintent'), isFalse, reason: path);
      expect(source.contains('add_to_cart'), isFalse, reason: path);
    }
  });
}
