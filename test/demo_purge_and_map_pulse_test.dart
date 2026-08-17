import 'dart:io';

import 'package:firstvue/services/demo_accounts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String osmMap;
  late String nativeMap;
  late String authScreen;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20261017_demo_auto_purge_after_ten_users.sql',
    ).readAsStringSync();
    osmMap = File('lib/widgets/live/live_map_surface_osm.dart').readAsStringSync();
    nativeMap =
        File('lib/widgets/live/live_map_surface_native.dart').readAsStringSync();
    authScreen = File('lib/screens/auth_screen.dart').readAsStringSync();
  });

  group('demo auto-purge migration', () {
    test('purges after ten real users and exposes public status RPC', () {
      expect(migration, contains('fv_purge_demo_pack'));
      expect(migration, contains('fv_maybe_purge_demo_pack'));
      expect(migration, contains('fv_demo_accounts_status'));
      expect(migration, contains('v_threshold constant int := 10'));
      expect(migration, contains('trg_profiles_maybe_purge_demos'));
      expect(
        migration,
        contains(
          'grant execute on function public.fv_demo_accounts_status() to anon, authenticated',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.fv_purge_demo_pack() to service_role',
        ),
      );
    });

    test('skips demo seed identities when counting and purging', () {
      expect(migration, contains("%@firstvue.demo"));
      expect(migration, contains("fvdemo_%"));
      expect(migration, contains('coalesce(new.is_demo, false)'));
    });
  });

  group('demo accounts status model', () {
    test('parses available payload', () {
      final status = DemoAccountsStatus.fromJson({
        'available': true,
        'email': 'fvdemo01@firstvue.demo',
        'username': 'fvdemo_maya',
        'password': 'FirstVueDemo!25',
        'real_users': 5,
        'threshold': 10,
        'message': 'Demo accounts are available',
      });
      expect(status.available, isTrue);
      expect(status.email, 'fvdemo01@firstvue.demo');
      expect(status.password, 'FirstVueDemo!25');
      expect(status.realUsers, 5);
      expect(status.threshold, 10);
    });

    test('parses unavailable payload after purge', () {
      final status = DemoAccountsStatus.fromJson({
        'available': false,
        'real_users': 12,
        'threshold': 10,
      });
      expect(status.available, isFalse);
      expect(status.email, isNull);
      expect(status.realUsers, 12);
    });
  });

  group('auth demo banner wiring', () {
    test('auth screen loads demo status and can hide banner', () {
      expect(authScreen, contains('DemoAccountsService.fetchStatus'));
      expect(authScreen, contains('_DemoAccountsBanner'));
      expect(authScreen, contains('_demoStatus.available'));
      expect(authScreen, contains('auth-use-demo-button'));
    });
  });

  group('live map pin pulse', () {
    test('OSM pins paint animated ripples under live markers', () {
      expect(osmMap, contains('_PinRipplePainter'));
      expect(osmMap, contains('AnimationController'));
      expect(osmMap, contains('_pulse.repeat()'));
    });

    test('Mapbox surface pulses glow circle radii for live pins', () {
      expect(nativeMap, contains('_GlowCircleRef'));
      expect(nativeMap, contains('_applyGlowPulse'));
      expect(nativeMap, contains("customData: {'pinId': pin.id, 'glow': true"));
    });
  });
}
