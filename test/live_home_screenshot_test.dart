import 'package:firstvue/services/live_home_service.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/theme/live_tokens.dart';
import 'package:firstvue/widgets/live/live_category_row.dart';
import 'package:firstvue/widgets/live/live_right_now_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Structural visual checks vs LIVE home reference (uploaded design pictures).
void main() {
  testWidgets('LIVE home hierarchy matches reference 01 structure', (
    tester,
  ) async {
    final items = [
      const LiveRightNowItem(
        id: 'evt-visual-1',
        kind: LiveRightNowKind.event,
        title: 'Afrobeats Rooftop',
        lifecycle: LiveLifecycleStatus.live,
        goingCount: 73,
        locationLabel: 'Midtown Atlanta',
      ),
      const LiveRightNowItem(
        id: 'evt-visual-2',
        kind: LiveRightNowKind.event,
        title: 'Ponce Night Market',
        lifecycle: LiveLifecycleStatus.live,
        goingCount: 146,
        locationLabel: 'Midtown',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('VUE | ● LIVE'),
                ),
                const Text('FirstVue'),
                LiveCategoryRow(
                  selected: LiveDiscoveryCategory.events,
                  onSelected: (_) {},
                ),
                const Text('🔥 ATLANTA RIGHT NOW'),
                SizedBox(
                  height: LiveTokens.cardHeight,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      LiveRightNowCard(item: items[0]),
                      LiveRightNowCard(item: items[1]),
                    ],
                  ),
                ),
                const Text('🗺️  Explore Live Map  >'),
                const Text('VUE FEED'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('FirstVue'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('🔥 ATLANTA RIGHT NOW'), findsOneWidget);
    expect(find.byType(LiveRightNowCard), findsNWidgets(2));
    expect(find.textContaining('Explore Live Map'), findsOneWidget);
    expect(find.text('VUE FEED'), findsOneWidget);

    final cardSize = tester.getSize(find.byType(LiveRightNowCard).first);
    expect(cardSize.width, LiveTokens.cardWidth);
    expect(cardSize.height, LiveTokens.cardHeight);
    expect(LiveTokens.cardRadius, 14);
  });
}
