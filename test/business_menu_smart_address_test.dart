import 'package:firstvue/services/business_menu_service.dart';
import 'package:firstvue/widgets/smart_address_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BusinessMenuService dining + grouping', () {
    test('isDiningBusinessType detects restaurant-like types', () {
      expect(BusinessMenuService.isDiningBusinessType('Restaurant'), isTrue);
      expect(BusinessMenuService.isDiningBusinessType('Cafe & Bakery'), isTrue);
      expect(BusinessMenuService.isDiningBusinessType('Salon spa'), isFalse);
      expect(BusinessMenuService.isDiningBusinessType('Food truck'), isTrue);
    });

    test('groupByCategory preserves order and filters unavailable', () {
      const items = [
        BusinessMenuItem(
          id: '1',
          name: 'Burger',
          description: null,
          priceLabel: '\$12',
          category: 'Mains',
          isAvailable: true,
          sortOrder: 1,
        ),
        BusinessMenuItem(
          id: '2',
          name: 'Fries',
          description: null,
          priceLabel: '\$4',
          category: 'Sides',
          isAvailable: true,
          sortOrder: 0,
        ),
        BusinessMenuItem(
          id: '3',
          name: 'Steak',
          description: null,
          priceLabel: '\$28',
          category: 'Mains',
          isAvailable: false,
          sortOrder: 0,
        ),
        BusinessMenuItem(
          id: '4',
          name: 'Salad',
          description: null,
          priceLabel: '\$9',
          category: 'Mains',
          isAvailable: true,
          sortOrder: 2,
        ),
      ];

      final all = BusinessMenuService.groupByCategory(items);
      expect(all.map((g) => g.name).toList(), ['Mains', 'Sides']);
      expect(all.first.items.map((i) => i.id).toList(), ['3', '1', '4']);

      final available = BusinessMenuService.groupByCategory(
        items,
        includeUnavailable: false,
      );
      expect(available.first.items.map((i) => i.id).toList(), ['1', '4']);
      expect(available.length, 2);
    });
  });

  group('SmartAddressLogic', () {
    test('shouldSuggest gates on min length', () {
      expect(SmartAddressLogic.shouldSuggest('ab'), isFalse);
      expect(SmartAddressLogic.shouldSuggest('abc'), isTrue);
      expect(SmartAddressLogic.debounceMs, 300);
    });

    test('parseLocalQuery extracts street/city/state/zip', () {
      final parsed = SmartAddressLogic.parseLocalQuery(
        '123 Main St, Austin, TX 78701',
      );
      expect(parsed.street, '123 Main St');
      expect(parsed.city, 'Austin');
      expect(parsed.state, 'TX');
      expect(parsed.zip, '78701');
      expect(parsed.country, 'US');
      expect(parsed.formatted, contains('Austin'));
    });

    test('localSuggestions return stubs after 3 characters', () {
      expect(SmartAddressLogic.localSuggestions('ab'), isEmpty);
      final suggestions = SmartAddressLogic.localSuggestions('Main');
      expect(suggestions, isNotEmpty);
      expect(suggestions.first.primaryText.toLowerCase(), contains('main'));
    });
  });
}
