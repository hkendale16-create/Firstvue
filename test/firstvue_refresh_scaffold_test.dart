import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/firstvue_refresh_scaffold.dart';

void main() {
  testWidgets('pull-to-refresh ignores rapid repeat triggers', (tester) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: FirstVueRefreshScaffold(
          playRefreshSound: false,
          onRefresh: () async {
            refreshes += 1;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            children: List.generate(
              20,
              (i) => SizedBox(height: 80, child: Text('row $i')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.text('row 0'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.fling(find.text('row 0'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Debounce / in-flight guard should keep this from stacking many reloads.
    expect(refreshes, lessThanOrEqualTo(1));
  });
}
