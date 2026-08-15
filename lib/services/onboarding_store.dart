import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStore {
  OnboardingStore._();

  /// Bumped to v2 so first-time users get the events/connection welcome +
  /// optional section & business-entity tours. Users who already finished v1
  /// keep their completed state via the migration helpers below.
  static const _welcomeKey = 'firstvue_welcome_v2_seen';
  static const _tutorialKey = 'firstvue_tutorial_v2_completed';
  static const _legacyWelcomeKey = 'firstvue_welcome_v1_seen';
  static const _legacyTutorialKey = 'firstvue_tutorial_v1_completed';

  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_welcomeKey) ?? false) return false;
    // Respect prior first-launch completion so returning devices are not nudged.
    if (prefs.getBool(_legacyWelcomeKey) ?? false) {
      await prefs.setBool(_welcomeKey, true);
      return false;
    }
    return true;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }

  static Future<bool> shouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tutorialKey) ?? false) return false;
    if (prefs.getBool(_legacyTutorialKey) ?? false) {
      await prefs.setBool(_tutorialKey, true);
      return false;
    }
    return true;
  }

  static Future<void> markTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialKey, true);
  }

  /// Clears first-launch flags so the welcome + tour can run again.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_welcomeKey);
    await prefs.remove(_tutorialKey);
    await prefs.remove(_legacyWelcomeKey);
    await prefs.remove(_legacyTutorialKey);
  }
}
