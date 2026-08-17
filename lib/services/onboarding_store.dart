import 'package:shared_preferences/shared_preferences.dart';

/// Sections that can show a short, contextual tip when visited.
enum TutorialSection {
  home,
  vue,
  feeds,
  explore,
  messages,
  settings,
  profile,
  theme,
}

/// Why the first-launch / tips flow should run for this session.
enum TutorialPromptKind {
  /// Brand-new device / first signed-in visit.
  welcome,

  /// Returning user after a shipped feature/tutorial update.
  whatsNew,
}

class OnboardingStore {
  OnboardingStore._();

  /// Bump when shipping tutorial copy or feature updates so tips show again.
  ///
  /// New users always get [TutorialPromptKind.welcome]. Existing users who
  /// already finished tips see [TutorialPromptKind.whatsNew] when this rises.
  ///
  /// This value must only change for meaningful tutorial content updates
  /// (new sections, materially different copy) — not on every release —
  /// so the tour does not resurface on every login.
  static const contentVersion = 4;

  /// Welcome dialog (v4 copy — expanded FirstVue overview + tip preview).
  static const _welcomeKey = 'firstvue_welcome_v4_seen';
  static const _legacyWelcomeV3Key = 'firstvue_welcome_v3_seen';
  static const _legacyWelcomeV2Key = 'firstvue_welcome_v2_seen';
  static const _legacyWelcomeV1Key = 'firstvue_welcome_v1_seen';

  /// When true, section tips are suppressed (user skipped or finished all).
  static const _tipsOptOutKey = 'firstvue_tips_v4_opt_out';
  static const _legacyTutorialV3Key = 'firstvue_tips_v3_opt_out';
  static const _legacyTutorialV2Key = 'firstvue_tutorial_v2_completed';
  static const _legacyTutorialV1Key = 'firstvue_tutorial_v1_completed';

  static const _seenContentVersionKey = 'firstvue_tutorial_content_version';
  static const _pendingWhatsNewKey = 'firstvue_tutorial_whats_new_pending';

  static String _tipKey(TutorialSection section) =>
      'firstvue_tip_v4_${section.name}_seen';

  /// Call once per signed-in home session before showing tips.
  ///
  /// Applies content-version bumps (re-enable tips + What's new) and migrates
  /// legacy slide-tutorial completion into the versioned tip system.
  static Future<void> prepareForSession() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getInt(_seenContentVersionKey);

    if (seen == contentVersion) return;

    if (seen != null && seen < contentVersion) {
      // Feature/tutorial update for someone already on the versioned system.
      // Carry forward "already welcomed" state under the new key name so a
      // storage-key rename never re-triggers the brand-new welcome dialog —
      // returning users always get What's new, never Welcome, on a bump.
      final alreadyWelcomed = (prefs.getBool(_welcomeKey) ?? false) ||
          (prefs.getBool(_legacyWelcomeV3Key) ?? false) ||
          (prefs.getBool(_legacyWelcomeV2Key) ?? false) ||
          (prefs.getBool(_legacyWelcomeV1Key) ?? false);
      if (alreadyWelcomed) {
        await prefs.setBool(_welcomeKey, true);
      }
      await _clearTipProgress(prefs);
      await prefs.setBool(_pendingWhatsNewKey, true);
      await prefs.setInt(_seenContentVersionKey, contentVersion);
      return;
    }

    // First time on the versioned tip system (seen == null).
    final legacyWelcome = (prefs.getBool(_legacyWelcomeV3Key) ?? false) ||
        (prefs.getBool(_legacyWelcomeV2Key) ?? false) ||
        (prefs.getBool(_legacyWelcomeV1Key) ?? false);
    final legacyTutorial = (prefs.getBool(_legacyTutorialV3Key) ?? false) ||
        (prefs.getBool(_legacyTutorialV2Key) ?? false) ||
        (prefs.getBool(_legacyTutorialV1Key) ?? false);

    if (legacyWelcome && !(prefs.getBool(_welcomeKey) ?? false)) {
      await prefs.setBool(_welcomeKey, true);
    }

    if (legacyTutorial) {
      // Treat the old slide tour as completed for a prior version, then
      // re-offer contextual tips as an update — not a brand-new welcome.
      await prefs.remove(_legacyTutorialV2Key);
      await prefs.remove(_legacyTutorialV1Key);
      await _clearTipProgress(prefs);
      await prefs.setBool(_pendingWhatsNewKey, true);
      if (!(prefs.getBool(_welcomeKey) ?? false)) {
        await prefs.setBool(_welcomeKey, true);
      }
    }

    await prefs.setInt(_seenContentVersionKey, contentVersion);
  }

  static Future<bool> shouldShowWelcome() async {
    await prepareForSession();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_welcomeKey) ?? false) return false;
    return true;
  }

  static Future<bool> shouldShowWhatsNew() async {
    await prepareForSession();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingWhatsNewKey) ?? false;
  }

  /// Prefer welcome for brand-new users; What's new after updates.
  static Future<TutorialPromptKind?> pendingPrompt() async {
    if (await shouldShowWelcome()) return TutorialPromptKind.welcome;
    if (await shouldShowWhatsNew()) return TutorialPromptKind.whatsNew;
    return null;
  }

  static Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeKey, true);
  }

  static Future<void> markWhatsNewSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingWhatsNewKey, false);
  }

  /// Whether contextual tips may still appear for any section.
  static Future<bool> tipsEnabled() async {
    await prepareForSession();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tipsOptOutKey) ?? false) return false;
    return true;
  }

  static Future<bool> shouldShowTip(TutorialSection section) async {
    await prepareForSession();
    final prefs = await SharedPreferences.getInstance();
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
    await prefs.setBool(_pendingWhatsNewKey, false);
  }

  /// Clears tip progress so tips can appear again (Settings → App tutorial).
  static Future<void> resetTips() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearTipProgress(prefs);
    await prefs.remove(_legacyTutorialV3Key);
    await prefs.remove(_legacyTutorialV2Key);
    await prefs.remove(_legacyTutorialV1Key);
  }

  /// Clears first-launch flags so welcome + tips can run again.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_welcomeKey);
    await prefs.remove(_legacyWelcomeV3Key);
    await prefs.remove(_legacyWelcomeV2Key);
    await prefs.remove(_legacyWelcomeV1Key);
    await prefs.remove(_seenContentVersionKey);
    await prefs.remove(_pendingWhatsNewKey);
    await resetTips();
  }

  static Future<void> _clearTipProgress(SharedPreferences prefs) async {
    for (final s in TutorialSection.values) {
      await prefs.remove(_tipKey(s));
    }
    await prefs.remove(_tipsOptOutKey);
  }
}
