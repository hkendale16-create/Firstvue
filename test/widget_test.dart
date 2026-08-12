import 'package:firstvue/config/supabase_config.dart';
import 'package:firstvue/main.dart';
import 'package:flutter/material.dart';
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

    final homeScrollable = find.byType(Scrollable).first;

    // Trending section loads async; wait for tabs to appear at top of home.
    expect(find.text('TRENDING NEAR YOU'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('NEWS FEED'),
      300,
      scrollable: homeScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('NEWS FEED'), findsOneWidget);
    expect(find.text('POST HERE'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('EXPLORE'),
      300,
      scrollable: homeScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE'), findsOneWidget);
    expect(find.text('BARBER & BEAUTY'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text("WHAT'S NOW"),
      300,
      scrollable: homeScrollable,
    );
    await tester.pumpAndSettle();

    expect(find.text("WHAT'S NOW"), findsOneWidget);
    expect(find.text('TRENDING & EVENTS'), findsOneWidget);
  });
}
