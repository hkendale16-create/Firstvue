import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/firstvue_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('welcome asks to see nearby instead of touring eight chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const FirstVueWelcomeDialog(),
      ),
    );

    expect(find.text('Welcome to FirstVue'), findsOneWidget);
    expect(find.text('See what\'s nearby'), findsOneWidget);
    expect(find.text('I\'ll explore on my own'), findsOneWidget);
    expect(find.text('Yes — show me around'), findsNothing);
    expect(find.text('Nearby'), findsOneWidget);
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Communities & Groups'), findsNothing);
  });
}
