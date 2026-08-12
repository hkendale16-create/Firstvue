import 'package:flutter/material.dart';

import '../services/theme_preference_service.dart';

/// App-wide theme mode controller. Changing [themeMode] rebuilds MaterialApp
/// immediately and persists the choice locally.
class AppThemeController extends ChangeNotifier {
  AppThemeController();

  ThemeMode _themeMode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _themeMode = await ThemePreferenceService.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await ThemePreferenceService.save(mode);
  }
}

/// Global instance wired from [main] so settings can update without prop drilling.
final appThemeController = AppThemeController();
