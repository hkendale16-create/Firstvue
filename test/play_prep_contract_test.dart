import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payments default off and checkout is gated', () {
    final flags = File('lib/config/feature_flags.dart').readAsStringSync();
    expect(flags, contains('FIRSTVUE_PAYMENTS'));
    expect(flags, contains('defaultValue: false'));
    final stripe = File('lib/services/stripe_billing_service.dart').readAsStringSync();
    expect(stripe, contains('FeatureFlags.effectiveBusinessSubscriptions'));
  });

  test('account deletion UI and edge function exist', () {
    expect(File('lib/services/account_deletion_service.dart').existsSync(), isTrue);
    expect(File('supabase/functions/delete-account/index.ts').existsSync(), isTrue);
    final privacy = File('lib/screens/privacy_settings_screen.dart').readAsStringSync();
    expect(privacy, contains('Delete account'));
  });

  test('android namespace matches applicationId', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('namespace = "app.firstvue.mobile"'));
    expect(gradle, contains('applicationId = "app.firstvue.mobile"'));
    expect(
      File('android/app/src/main/kotlin/app/firstvue/mobile/MainActivity.kt')
          .existsSync(),
      isTrue,
    );
  });
}
