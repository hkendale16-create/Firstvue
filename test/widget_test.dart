import 'package:firstvue/auth/auth_session_controller.dart';
import 'package:firstvue/config/supabase_config.dart';
import 'package:firstvue/main.dart';
import 'package:firstvue/screens/auth_screen.dart';
import 'package:firstvue/widgets/fv_gold_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v1_seen': true,
      'firstvue_tutorial_v1_completed': true,
    });
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  });

  testWidgets('signed-out FirstVueApp shows the auth wall, not home nav', (
    tester,
  ) async {
    await tester.pumpWidget(
      FirstVueApp(authController: AuthSessionController.test()),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
    expect(find.byType(FvGoldButton), findsOneWidget);
    expect(find.text('Sign in or create account'), findsNothing);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('FEEDS'), findsNothing);
    expect(find.text('EXPLORE'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });
}
