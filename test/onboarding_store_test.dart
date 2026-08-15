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
    expect(await OnboardingStore.tipsEnabled(), isTrue);
    expect(await OnboardingStore.shouldShowTip(TutorialSection.messages), isTrue);
  });

  test('marking welcome and tips suppresses future prompts', () async {
    await OnboardingStore.markWelcomeSeen();
    await OnboardingStore.markAllTipsSeen();
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
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

  test('legacy v2 completion migrates without re-prompting tips', () async {
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v2_seen': true,
      'firstvue_tutorial_v2_completed': true,
    });
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.tipsEnabled(), isFalse);
    expect(
      await OnboardingStore.shouldShowTip(TutorialSection.explore),
      isFalse,
    );
  });

  test('legacy v1 completion migrates without re-prompting', () async {
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v1_seen': true,
      'firstvue_tutorial_v1_completed': true,
    });
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.tipsEnabled(), isFalse);
  });
}
