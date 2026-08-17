import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firstvue/services/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OnboardingStore.reset();
  });

  test('first launch shows welcome and section tips', () async {
    expect(await OnboardingStore.shouldShowWelcome(), isTrue);
    expect(await OnboardingStore.pendingPrompt(), TutorialPromptKind.welcome);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
    expect(await OnboardingStore.shouldShowTip(TutorialSection.messages), isTrue);
  });

  test('marking welcome and tips suppresses future prompts', () async {
    await OnboardingStore.markWelcomeSeen();
    await OnboardingStore.markAllTipsSeen();
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.shouldShowWhatsNew(), isFalse);
    expect(await OnboardingStore.tipsEnabled(), isFalse);
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.home),
      isFalse,
    );
  });

  test('section tips are independent until all are seen', () async {
    await OnboardingStore.markTipSeen(TutorialSection.messages);
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.messages),
      isFalse,
    );
    expect(await OnboardingStore.shouldShowTip(TutorialSection.home), isTrue);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
  });

  test('resetTips re-enables contextual tips', () async {
    await OnboardingStore.markAllTipsSeen();
    await OnboardingStore.resetTips();
    expect(await OnboardingStore.tipsEnabled(), isTrue);
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.vue),
      isTrue,
    );
  });

  test('legacy v2 users get What\'s new tips after update, not welcome', () async {
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v2_seen': true,
      'firstvue_tutorial_v2_completed': true,
    });
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.shouldShowWhatsNew(), isTrue);
    expect(await OnboardingStore.pendingPrompt(), TutorialPromptKind.whatsNew);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.explore),
      isTrue,
    );
  });

  test('legacy v1 users get What\'s new after update', () async {
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v1_seen': true,
      'firstvue_tutorial_v1_completed': true,
    });
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.shouldShowWhatsNew(), isTrue);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
  });

  test('content version bump re-shows What\'s new and tips', () async {
    await OnboardingStore.markWelcomeSeen();
    await OnboardingStore.markAllTipsSeen();
    expect(await OnboardingStore.tipsEnabled(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'firstvue_tutorial_content_version',
      OnboardingStore.contentVersion - 1,
    );

    expect(await OnboardingStore.shouldShowWhatsNew(), isTrue);
    expect(await OnboardingStore.pendingPrompt(), TutorialPromptKind.whatsNew);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
    expect(await OnboardingStore.shouldShowTip(TutorialSection.home), isTrue);
  });

  test('content version bump never re-shows Welcome for an already-welcomed '
      'user, even when the welcome storage key is renamed', () async {
    // Simulate a returning user who finished onboarding on the previous
    // versioned welcome key before this version's key existed.
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v3_seen': true,
      'firstvue_tips_v3_opt_out': true,
      'firstvue_tutorial_content_version': OnboardingStore.contentVersion - 1,
    });

    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.pendingPrompt(), TutorialPromptKind.whatsNew);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
  });

  test('does not re-show the tour on a routine app open at the same content '
      'version (tutorial should not appear every login)', () async {
    await OnboardingStore.markWelcomeSeen();
    await OnboardingStore.markAllTipsSeen();

    // Re-entering the app repeatedly at the same content version must not
    // resurface welcome, what's new, or tips.
    for (var i = 0; i < 3; i++) {
      expect(await OnboardingStore.shouldShowWelcome(), isFalse);
      expect(await OnboardingStore.shouldShowWhatsNew(), isFalse);
      expect(await OnboardingStore.tipsEnabled(), isFalse);
      expect(await OnboardingStore.pendingPrompt(), isNull);
    }
  });

  test('new profile and theme tutorial sections behave like other sections',
      () async {
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.profile),
      isTrue,
    );
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.theme),
      isTrue,
    );

    await OnboardingStore.markTipSeen(TutorialSection.profile);
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.profile),
      isFalse,
    );
    // Other sections remain unaffected until every section is individually
    // marked seen.
    expect(await OnboardingStore.shouldShowTip(TutorialSection.theme), isTrue);
    expect(await OnboardingStore.tipsEnabled(), isTrue);
  });

  test('opt-out only triggers once every section — including profile and '
      'theme — has been marked seen', () async {
    for (final section in TutorialSection.values) {
      if (section == TutorialSection.theme) continue;
      await OnboardingStore.markTipSeen(section);
    }
    expect(await OnboardingStore.tipsEnabled(), isTrue);

    await OnboardingStore.markTipSeen(TutorialSection.theme);
    expect(await OnboardingStore.tipsEnabled(), isFalse);
  });
}
