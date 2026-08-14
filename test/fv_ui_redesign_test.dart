import 'package:firstvue/constants/business_types.dart';
import 'package:firstvue/data/industry_catalog.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/fv_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary industries include beauty, food, services', () {
    final industries = primaryIndustryOptions();
    final slugs = industries.map((i) => i.slug).toSet();
    expect(slugs.contains('beauty-grooming'), isTrue);
    expect(slugs.contains('food-dining'), isTrue);
    expect(slugs.contains('professional-services'), isTrue);
    expect(slugs.contains('home-services'), isTrue);
    expect(slugs.contains('health-fitness'), isTrue);
  });

  test('business types depend on selected industry', () {
    final beauty = businessTypesForIndustry('beauty-grooming');
    expect(beauty.any((t) => t.slug == 'barbershop'), isTrue);
    expect(beauty.any((t) => t.slug == 'spa'), isTrue);

    final food = businessTypesForIndustry('food-dining');
    expect(food.any((t) => t.slug == 'restaurant'), isTrue);
    expect(food.any((t) => t.slug == 'barbershop'), isFalse);
  });

  test('editor tabs hide menu for barbershops', () {
    final beautyTabs = IndustryCatalog.editorTabsFor(displayType: 'Barbershop');
    expect(beautyTabs.contains('Menu'), isFalse);
    expect(beautyTabs.contains('Services'), isTrue);

    final foodTabs = IndustryCatalog.editorTabsFor(displayType: 'Restaurant');
    expect(foodTabs.contains('Menu'), isTrue);
    expect(foodTabs.contains('Services'), isFalse);
  });

  testWidgets('FvUnderlineTabs marks selected tab', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: FvUnderlineTabs(
            labels: const ['For You', 'Nearby', 'Trending'],
            selectedIndex: selected,
            onSelected: (i) => selected = i,
          ),
        ),
      ),
    );
    expect(find.text('For You'), findsOneWidget);
    await tester.tap(find.text('Nearby'));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('FvSettingsRow meets touch target height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: FvSettingsRow(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Profile visibility',
            onTap: () {},
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(FvSettingsRow));
    expect(size.height >= 44, isTrue);
  });
}
