import 'package:flutter/material.dart';

import '../services/theme_preference_service.dart';
import '../theme/app_theme_controller.dart';
import '../theme/firstvue_theme.dart';

/// Settings → Appearance → Theme
class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  static const _options = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Appearance'),
      ),
      body: ListenableBuilder(
        listenable: appThemeController,
        builder: (context, _) {
          final selected = appThemeController.themeMode;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'THEME',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Applies across FirstVue immediately. System Default follows '
                'your phone’s light/dark setting.',
                style: TextStyle(color: fv.secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ..._options.map((mode) {
                final active = selected == mode;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => appThemeController.setThemeMode(mode),
                  title: Text(
                    ThemePreferenceService.label(mode),
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: mode == ThemeMode.system
                      ? Text(
                          'Match iPhone / Android appearance',
                          style: TextStyle(
                            color: fv.tertiaryText,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: active
                      ? const Icon(Icons.check, color: FirstVueColors.teal)
                      : null,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
