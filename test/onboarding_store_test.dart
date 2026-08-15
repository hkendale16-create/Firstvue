import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firstvue/services/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OnboardingStore.reset();
  });

  test('first launch shows welcome and tutorial', () async {
    expect(await OnboardingStore.shouldShowWelcome(), isTrue);
    expect(await OnboardingStore.shouldShowTutorial(), isTrue);
  });

  test('marking welcome and tutorial suppresses future prompts', () async {
    await OnboardingStore.markWelcomeSeen();
    await OnboardingStore.markTutorialCompleted();
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.shouldShowTutorial(), isFalse);
  });

  test('legacy v1 completion migrates to v2 without re-prompting', () async {
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v1_seen': true,
      'firstvue_tutorial_v1_completed': true,
    });
    expect(await OnboardingStore.shouldShowWelcome(), isFalse);
    expect(await OnboardingStore.shouldShowTutorial(), isFalse);
  });
}
