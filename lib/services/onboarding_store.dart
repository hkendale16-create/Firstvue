import 'package:shared_preferences/shared_preferences.dart';

/// Sections that can show a short, contextual tip when visited.
enum TutorialSection {
  home,
  vue,
  feeds,
  explore,
  messages,
  settings,
}

class OnboardingStore {
  OnboardingStore._();

  /// Welcome dialog (v3 copy — contextual tips, no slide chooser).
  static const _welcomeKey = 'firstvue_welcome_v3_seen';
  static const _legacyWelcomeV2Key = 'firstvue_welcome_v2_seen';
  static const _legacyWelcomeV1Key = 'firstvue_welcome_v1_seen';

  /// When true, section tips are suppressed (user skipped or finished all).
  static const _tipsOptOutKey = 'firstvue_tips_v3_opt_out';
  static const _legacyTutorialV2Key = 'firstvue_tutorial_v2_completed';
  static const _legacyTutorialV1Key = 'firstvue_tutorial_v1_completed';

  static String _tipKey(TutorialSection section) =>
      'firstvue_tip_v3_${section.name}_seen';

  static Future<bool> shouldShowWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_welcomeKey) ?? false) return false;
    // Respect prior first-launch completion so returning devices are not nudged.
    if (prefs.getBool(_legacyWelcomeV2Key) ?? false) {
      await prefs.setBool(_welcomeKey, true);
      return false;
    }
    if (prefs.getBool(_legacyWelcomeV1Key) ?? false) {
      await prefs.setBool(_welcomeKey, true);
      return false;
    }
    return true;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }

  /// Whether contextual tips may still appear for any section.
  static Future<bool> tipsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTutorial(prefs);
    if (prefs.getBool(_tipsOptOutKey) ?? false) return false;
    return true;
  }

  static Future<bool> shouldShowTip(TutorialSection section) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyTutorial(prefs);
    if (prefs.getBool(_tipsOptOutKey) ?? false) return false;
    return !(prefs.getBool(_tipKey(section)) ?? false);
  }

  static Future<void> markTipSeen(TutorialSection section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tipKey(section), true);
    // Opt out once every section tip has been seen.
    for (final s in TutorialSection.values) {
      if (!(prefs.getBool(_tipKey(s)) ?? false)) return;
    }
    await prefs.setBool(_tipsOptOutKey, true);
  }

  /// Skip remaining tips (welcome “maybe later”, tip “skip all”, or finish).
  static Future<void> markAllTipsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    for (final s in TutorialSection.values) {
      await prefs.setBool(_tipKey(s), true);
    }
    await prefs.setBool(_tipsOptOutKey, true);
  }

  /// Clears tip progress so tips can appear again (Settings → App tutorial).
  static Future<void> resetTips() async {
    final prefs = await SharedPreferences.getInstance();
    for (final s in TutorialSection.values) {
      await prefs.remove(_tipKey(s));
    }
    await prefs.remove(_tipsOptOutKey);
    await prefs.remove(_legacyTutorialV2Key);
    await prefs.remove(_legacyTutorialV1Key);
  }

  /// Clears first-launch flags so welcome + tips can run again.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_welcomeKey);
    await prefs.remove(_legacyWelcomeV2Key);
    await prefs.remove(_legacyWelcomeV1Key);
    await resetTips();
  }

  /// Users who finished the old slide tutorial should not see tips again.
  static Future<void> _migrateLegacyTutorial(SharedPreferences prefs) async {
    if (prefs.containsKey(_tipsOptOutKey)) return;
    final legacyDone = (prefs.getBool(_legacyTutorialV2Key) ?? false) ||
        (prefs.getBool(_legacyTutorialV1Key) ?? false);
    if (!legacyDone) return;
    for (final s in TutorialSection.values) {
      await prefs.setBool(_tipKey(s), true);
    }
    await prefs.setBool(_tipsOptOutKey, true);
  }
}
