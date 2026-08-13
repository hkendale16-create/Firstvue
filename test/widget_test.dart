import 'package:firstvue/config/supabase_config.dart';
import 'package:firstvue/main.dart';
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

  testWidgets('FirstVue home screen renders', (tester) async {
    await tester.pumpWidget(const FirstVueApp());
    await tester.pumpAndSettle();

    final homeNav = find.text('HOME');
    await tester.ensureVisible(homeNav);
    await tester.tap(homeNav);
    await tester.pumpAndSettle();

    expect(find.text('SEE FIRST. BOOK FIRST.'), findsOneWidget);
    expect(find.text('People to follow'), findsOneWidget);

    final exploreNav = find.text('EXPLORE');
    await tester.ensureVisible(exploreNav);
    await tester.tap(exploreNav);
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE'), findsWidgets);
  });
}
