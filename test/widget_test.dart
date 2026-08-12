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

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> dragHomeUntilFound(
    WidgetTester tester,
    Finder finder,
  ) async {
    for (var i = 0; i < 30; i++) {
      await pumpUntilFound(tester, finder, timeout: const Duration(milliseconds: 400));
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(find.byType(FirstVueApp), const Offset(0, -350));
      await tester.pump();
    }
  }

  testWidgets('FirstVue home screen renders', (tester) async {
    await tester.pumpWidget(const FirstVueApp());
    await tester.pumpAndSettle();

    final homeNav = find.text('HOME');
    await tester.ensureVisible(homeNav);
    await tester.tap(homeNav);
    await tester.pumpAndSettle();

    expect(find.text('YOUR COMMUNITY GROUPS'), findsOneWidget);
    expect(find.text('COMMUNITIES IN YOUR AREA'), findsOneWidget);

    await dragHomeUntilFound(tester, find.text('TRENDING NEAR YOU'));
    expect(find.text('TRENDING NEAR YOU'), findsOneWidget);

    await dragHomeUntilFound(tester, find.text('NEWS FEED'));
    expect(find.text('NEWS FEED'), findsOneWidget);

    final exploreNav = find.text('EXPLORE');
    await tester.ensureVisible(exploreNav);
    await tester.tap(exploreNav);
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE'), findsWidgets);
  });
}
