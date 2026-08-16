import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/constants/business_types.dart';
import 'package:firstvue/utils/form_validators.dart';

void main() {
  test('every primary industry exposes business types ending with Other', () {
    final industries = primaryIndustryOptions();
    expect(industries, isNotEmpty);
    expect(industries.last.slug, 'general-business');
    expect(industries.last.label, 'Other');

    for (final industry in industries) {
      final types = businessTypesForIndustry(industry.slug);
      expect(types, isNotEmpty, reason: industry.slug);
      expect(types.last.isOther, isTrue, reason: industry.slug);
      expect(types.last.label, 'Other');
      expect(types.where((t) => t.isOther).length, 1);
    }
  });

  test('food and beauty include expected types without duplicates', () {
    final food = businessTypesForIndustry('food-dining').map((t) => t.label);
    expect(food, containsAll(['Restaurant', 'Food Truck', 'Coffee Shop', 'Other']));
    expect(food.toSet().length, food.length);

    final beauty = businessTypesForIndustry('beauty-grooming').map((t) => t.label);
    expect(
      beauty,
      containsAll(['Barbershop', 'Hair Salon', 'Spa', 'Tattoo Shop', 'Other']),
    );
    expect(beauty.toSet().length, beauty.length);
  });

  test('form validators accept common optional contact values', () {
    expect(FormValidators.optionalEmail(''), isNull);
    expect(FormValidators.optionalEmail('a@b.com'), isNull);
    expect(FormValidators.optionalEmail('bad'), isNotNull);

    expect(FormValidators.optionalPhone(''), isNull);
    expect(FormValidators.optionalPhone('(404) 555-1212'), isNull);
    expect(FormValidators.optionalPhone('123'), isNotNull);

    expect(FormValidators.optionalWebsite(''), isNull);
    expect(FormValidators.optionalWebsite('firstvue.app'), isNull);
    expect(FormValidators.optionalWebsite('notaurl'), isNotNull);

    expect(FormValidators.optionalUsZip(''), isNull);
    expect(FormValidators.optionalUsZip('30301'), isNull);
    expect(FormValidators.optionalUsZip('30301-1234'), isNull);
    expect(FormValidators.optionalUsZip('abc'), isNotNull);
  });
}
