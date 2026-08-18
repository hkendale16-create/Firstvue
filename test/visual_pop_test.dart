import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/fv_gold_button.dart';
import 'package:firstvue/widgets/social_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected social pill uses dark ink on gold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: SocialPillTabs(
            labels: const ['Tonight', 'Weekend'],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Text>(find.text('Tonight'));
    expect(selected.style?.color, FirstVueColors.onGold);
    final idle = tester.widget<Text>(find.text('Weekend'));
    expect(idle.style?.color, isNot(FirstVueColors.onGold));
  });

  testWidgets('gold button label uses dark ink', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: FvGoldButton(label: 'Sign in', onPressed: () {}),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Sign in'));
    expect(label.style?.color, FirstVueColors.onGold);
    expect(FirstVueColors.goldGlow(), isNotEmpty);
  });
}
