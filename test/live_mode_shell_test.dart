import 'package:firstvue/config/feature_flags.dart';
import 'package:firstvue/screens/live_home_shell_screen.dart';
import 'package:firstvue/services/live_mode_preference.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/vue_live_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors Phase 1 VUE|LIVE shell wiring without DiscoveryFeedService/Supabase.
class _LiveModeHarness extends StatefulWidget {
  const _LiveModeHarness();

  @override
  State<_LiveModeHarness> createState() => _LiveModeHarnessState();
}

class _LiveModeHarnessState extends State<_LiveModeHarness> {
  FirstVueExperienceMode _mode = LiveModePreference.current;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final stored = await LiveModePreference.load();
    if (!mounted || stored == _mode) return;
    setState(() => _mode = stored);
  }

  Future<void> _setMode(FirstVueExperienceMode next) async {
    setState(() => _mode = next);
    await LiveModePreference.save(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          VueLiveModeSwitch(mode: _mode, onChanged: _setMode),
          Expanded(
            child: _mode == FirstVueExperienceMode.live
                ? LiveHomeShellScreen(
                    onReturnToVue: () => _setMode(FirstVueExperienceMode.vue),
                  )
                : const Center(child: Text('For You')),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LiveModePreference.debugReset();
  });

  test('LiveModePreference defaults to VUE and parses LIVE', () {
    expect(LiveModePreference.parse(null), FirstVueExperienceMode.vue);
    expect(LiveModePreference.parse('vue'), FirstVueExperienceMode.vue);
    expect(LiveModePreference.parse('LIVE'), FirstVueExperienceMode.live);
    expect(LiveModePreference.parse('live'), FirstVueExperienceMode.live);
  });

  test('LiveModePreference persists locally', () async {
    expect(await LiveModePreference.load(), FirstVueExperienceMode.vue);
    await LiveModePreference.save(FirstVueExperienceMode.live);
    LiveModePreference.debugReset(mode: FirstVueExperienceMode.vue);
    expect(await LiveModePreference.load(), FirstVueExperienceMode.live);
  });

  test('live_mode flag is distinct from livestream streaming flag', () {
    expect(FeatureFlags.liveModeEnabled, isTrue);
    expect(FeatureFlags.liveStreamingEnabled, isFalse);
    expect(FeatureFlags.liveMapEnabled, isFalse);
  });

  testWidgets('VueLiveModeSwitch reports selection changes', (tester) async {
    FirstVueExperienceMode mode = FirstVueExperienceMode.vue;
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: Center(
            child: VueLiveModeSwitch(
              mode: mode,
              onChanged: (next) => mode = next,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('LIVE'));
    await tester.pump();
    expect(mode, FirstVueExperienceMode.live);
  });

  testWidgets('LIVE shell offers return to VUE', (tester) async {
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: LiveHomeShellScreen(onReturnToVue: () => returned = true),
        ),
      ),
    );

    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('Real-time discovery is coming next.'), findsOneWidget);
    await tester.tap(find.text('Back to VUE'));
    await tester.pump();
    expect(returned, isTrue);
  });

  testWidgets('mode switch restores VUE and persists LIVE', (tester) async {
    SharedPreferences.setMockInitialValues({
      LiveModePreference.prefsKey: 'live',
    });
    LiveModePreference.debugReset();

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const _LiveModeHarness(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(VueLiveModeSwitch), findsOneWidget);
    expect(find.byType(LiveHomeShellScreen), findsOneWidget);
    expect(find.text('For You'), findsNothing);

    await tester.tap(find.text('VUE').first);
    await tester.pump();
    await tester.pump();

    expect(find.byType(LiveHomeShellScreen), findsNothing);
    expect(find.text('For You'), findsOneWidget);
    expect(LiveModePreference.current, FirstVueExperienceMode.vue);
  });
}
