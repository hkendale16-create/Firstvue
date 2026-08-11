import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  OnboardingStore._();

  static const _welcomeKey = 'firstvue_welcome_v1_seen';
  static const _tutorialKey = 'firstvue_tutorial_v1_completed';

  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_welcomeKey) ?? false);
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }

  static Future<bool> shouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_tutorialKey) ?? false);
  }

  static Future<void> markTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
  }

  /// For testing — clears first-launch flags on this device.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_welcomeKey);
    await prefs.remove(_tutorialKey);
  }
}
