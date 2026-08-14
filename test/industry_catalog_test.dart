import 'package:firstvue/data/industry_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndustryCatalog', () {
    test('uses slugs not display text as keys', () {
      expect(IndustryCatalog.bySlug('barbershop').slug, 'barbershop');
      expect(
        IndustryCatalog.bySlug('barbershop').template,
        IndustryTemplate.beauty,
      );
    });

    test('maps display types onto templates', () {
      expect(
        IndustryCatalog.fromDisplayType('Barbershop').template,
        IndustryTemplate.beauty,
      );
      expect(
        IndustryCatalog.fromDisplayType('Restaurant').template,
        IndustryTemplate.food,
      );
      expect(
        IndustryCatalog.fromDisplayType('Sports Bar').template,
        IndustryTemplate.nightlife,
      );
      expect(
        IndustryCatalog.fromDisplayType('Unknown Widget Shop').template,
        IndustryTemplate.retail,
      );
    });

    test('unsupported industries get general business, never drinks', () {
      final general = IndustryCatalog.previewFor(IndustryTemplate.general);
      expect(general.tabs.contains('DRINKS'), isFalse);
      expect(
        IndustryCatalog.drinksTabAllowed(IndustryTemplate.beauty),
        isFalse,
      );
      expect(
        IndustryCatalog.drinksTabAllowed(IndustryTemplate.nightlife),
        isTrue,
      );
    });

    test('industry change previews added hidden retained modules', () {
      final preview = IndustryCatalog.previewChange(
        from: IndustryTemplate.beauty,
        to: IndustryTemplate.food,
      );
      expect(preview.added, contains('Menu'));
      expect(preview.hidden, contains('Staff'));
      expect(preview.retained, contains('Pricing'));
    });

    test('barbershop tabs never include drinks', () {
      final tabs = IndustryCatalog.tabsFor(displayType: 'Barbershop');
      expect(tabs.contains('DRINKS'), isFalse);
      expect(tabs.contains('SERVICES'), isTrue);
    });
  });

  group('PricingMode', () {
    test('parses storage values', () {
      expect(PricingModeX.parse('starting_at'), PricingMode.startingAt);
      expect(PricingModeX.parse('free'), PricingMode.free);
      expect(PricingModeX.parse('contact'), PricingMode.contact);
      expect(PricingMode.exact.label, 'Exact');
    });
  });
}
