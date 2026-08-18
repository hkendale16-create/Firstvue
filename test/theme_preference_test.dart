import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firstvue/services/theme_preference_service.dart';
import 'package:firstvue/theme/app_theme_controller.dart';
import 'package:firstvue/theme/firstvue_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemePreferenceService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to light when no preference stored', () async {
      expect(await ThemePreferenceService.load(), ThemeMode.light);
    });

    test('persists and reloads light / dark / system', () async {
      await ThemePreferenceService.save(ThemeMode.light);
      expect(await ThemePreferenceService.load(), ThemeMode.light);

      await ThemePreferenceService.save(ThemeMode.dark);
      expect(await ThemePreferenceService.load(), ThemeMode.dark);

      await ThemePreferenceService.save(ThemeMode.system);
      expect(await ThemePreferenceService.load(), ThemeMode.system);
    });

    test('fromStorage maps unknown values to light', () {
      expect(ThemePreferenceService.fromStorage(null), ThemeMode.light);
      expect(ThemePreferenceService.fromStorage('nope'), ThemeMode.light);
      expect(ThemePreferenceService.fromStorage('light'), ThemeMode.light);
    });
  });

  group('AppThemeController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('setThemeMode notifies and persists immediately', () async {
      final controller = AppThemeController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.load();
      expect(controller.themeMode, ThemeMode.light);

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(notifications, greaterThanOrEqualTo(2));
      expect(await ThemePreferenceService.load(), ThemeMode.dark);
    });
  });

  group('FirstVueTheme', () {
    test('light and dark ThemeData expose FirstVuePalette', () {
      final dark = FirstVueTheme.elegantDark;
      final light = FirstVueTheme.elegantLight;

      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);

      final darkPalette = dark.extension<FirstVuePalette>();
      final lightPalette = light.extension<FirstVuePalette>();
      expect(darkPalette, isNotNull);
      expect(lightPalette, isNotNull);
      expect(darkPalette!.background, isNot(equals(lightPalette!.background)));
      expect(darkPalette.primaryText, isNot(equals(lightPalette.primaryText)));
    });

    testWidgets('MaterialApp themeMode switches ThemeData', (tester) async {
      final controller = AppThemeController();
      await controller.load();

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return MaterialApp(
              theme: FirstVueTheme.elegantLight,
              darkTheme: FirstVueTheme.elegantDark,
              themeMode: controller.themeMode,
              home: const _BrightnessProbe(),
            );
          },
        ),
      );

      await controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);

      await controller.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
    });
  });

  group('visual pop tokens', () {
    test('onGold is dark ink, not white', () {
      expect(FirstVueColors.onGold.computeLuminance(), lessThan(0.2));
      expect(FirstVueColors.onGold, isNot(Colors.white));
    });

    test('filled buttons use dark ink on gold in both themes', () {
      for (final theme in [
        FirstVueTheme.elegantDark,
        FirstVueTheme.elegantLight,
      ]) {
        expect(theme.colorScheme.primary, FirstVueColors.gold);
        expect(theme.colorScheme.onPrimary, FirstVueColors.onGold);
        expect(
          theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
          FirstVueColors.onGold,
        );
        expect(
          theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
          FirstVueColors.gold,
        );
      }
    });
  });
}

class _BrightnessProbe extends StatelessWidget {
  const _BrightnessProbe();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Text(Theme.of(context).brightness.name),
    );
  }
}
