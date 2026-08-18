import 'package:firstvue/screens/business_owner_start_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('business tools exposes Claim / Add / Rental tab labels', () {
    expect(BusinessOwnerStartScreen.tabLabels, ['Claim', 'Add', 'Rental']);
  });

  testWidgets('business tools shows horizontal tabs, not stacked cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const BusinessOwnerStartScreen(),
      ),
    );

    final claim = tester.getTopLeft(find.text('Claim'));
    final add = tester.getTopLeft(find.text('Add'));
    final rental = tester.getTopLeft(find.text('Rental'));
    expect(add.dx, greaterThan(claim.dx));
    expect(rental.dx, greaterThan(add.dx));
    expect((claim.dy - add.dy).abs(), lessThan(2));
    expect((add.dy - rental.dy).abs(), lessThan(2));

    expect(find.text('Claim a listed business'), findsOneWidget);
    expect(find.text('Elite Fade Studio'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Add an unlisted business'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.text('Rental'));
    await tester.pumpAndSettle();
    expect(find.text('Post an available rental'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });
}
