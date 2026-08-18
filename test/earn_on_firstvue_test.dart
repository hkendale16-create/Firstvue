import 'package:firstvue/config/monetization_config.dart';
import 'package:firstvue/screens/earn_on_firstvue_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/earn_on_firstvue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('earn hub explains both sides without checkout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const EarnOnFirstVueScreen(),
      ),
    );

    expect(find.text('Earn on FirstVue'), findsOneWidget);
    expect(find.text('Become a creator'), findsOneWidget);
    expect(find.text('Draft a bounty'), findsOneWidget);
    expect(find.textContaining('Creators keep 85%'), findsWidgets);
    expect(find.textContaining('Stripe'), findsOneWidget);
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('Home earn card opens the hub', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const Scaffold(body: EarnOnFirstVueCard()),
      ),
    );
    expect(find.text('Earn on FirstVue'), findsOneWidget);
    expect(find.textContaining('85% to you'), findsOneWidget);
    await tester.tap(find.byType(EarnOnFirstVueCard));
    await tester.pumpAndSettle();
    expect(find.byType(EarnOnFirstVueScreen), findsOneWidget);
  });

  test('draft pool math stays in integer cents', () {
    expect(
      EarnMarketplace.poolCents(perCreatorCents: 2500, creatorsWanted: 3),
      7500,
    );
    expect(
      EarnMarketplace.poolCents(perCreatorCents: 0, creatorsWanted: 2),
      0,
    );
  });
}
