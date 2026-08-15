import 'dart:async';

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
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Debounce / in-flight guard should keep this from stacking many reloads.
    expect(refreshes, lessThanOrEqualTo(1));
  });

  testWidgets('pull-to-refresh completes and dismisses indicator', (
    tester,
  ) async {
    var refreshes = 0;
    final refreshDone = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: FirstVueRefreshScaffold(
          playRefreshSound: false,
          onRefresh: () async {
            refreshes += 1;
            await Future<void>.delayed(const Duration(milliseconds: 40));
            if (!refreshDone.isCompleted) refreshDone.complete();
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

    // Drag far enough to arm, then release so ScrollEnd can start refresh.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('row 0')),
    );
    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(refreshes, 1);
    expect(refreshDone.isCompleted, isTrue);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });
}
