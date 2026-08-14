import 'package:firstvue/auth/auth_gate.dart';
import 'package:firstvue/auth/auth_redirect.dart';
import 'package:firstvue/auth/auth_session_controller.dart';
import 'package:firstvue/main.dart';
import 'package:firstvue/screens/auth_screen.dart';
import 'package:firstvue/services/deep_link_service.dart';
import 'package:firstvue/widgets/firstvue_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session _fakeSession() {
  return Session(
    accessToken: 'test-access-token',
    tokenType: 'bearer',
    user: User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'firstvue_welcome_v1_seen': true,
      'firstvue_tutorial_v1_completed': true,
    });
  });

  testWidgets('signed-out users land on Sign in', (tester) async {
    final auth = AuthSessionController.test();
    await tester.pumpWidget(
      MaterialApp(home: AuthGate(controller: auth)),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('VUE'), findsNothing);
  });

  testWidgets('signed-in users normally land on VUE', (tester) async {
    final auth = AuthSessionController.test(session: _fakeSession());
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          controller: auth,
          signedInHome: Scaffold(
            body: const Text('VUE_SHELL'),
            bottomNavigationBar: FirstVueBottomNav(
              selectedIndex: FirstVueBottomNav.vueIndex,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('VUE_SHELL'), findsOneWidget);
    expect(find.text('VUE'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
  });

  test('FirstVueHome defaults to the VUE tab index', () {
    expect(const FirstVueHome().initialTab, isNull);
    expect(FirstVueBottomNav.vueIndex, 2);
  });

  test('protected deep links are remembered for post-auth return', () {
    final auth = AuthSessionController.test();
    auth.rememberRoute('/messages');
    auth.rememberDeepLink(const DeepLinkTarget(type: 'post', id: 'post-1'));

    expect(auth.pendingRoute, '/messages');
    expect(auth.pendingDeepLink?.type, 'post');
    expect(auth.pendingDeepLink?.id, 'post-1');

    final route = auth.takePendingRoute();
    final link = auth.takePendingDeepLink();
    expect(route, '/messages');
    expect(link?.id, 'post-1');
    expect(auth.pendingRoute, isNull);
    expect(auth.pendingDeepLink, isNull);
  });

  test('signed-in auth routes resolve to FirstVueHome shell', () {
    final auth = AuthSessionController.test(session: _fakeSession());
    final route = generateAuthAwareRoute(
      const RouteSettings(name: '/signin'),
      controller: auth,
    );
    expect(route.settings.name, '/');
    expect(shouldRedirectSignedInToHome('/signin'), isTrue);
  });

  test('vue and explore are allowed post-auth redirects', () {
    expect(sanitizeAuthRedirect('/vue'), '/vue');
    expect(sanitizeAuthRedirect('/explore'), '/explore');
    expect(FirstVueBottomNav.indexForRoute('/vue'), FirstVueBottomNav.vueIndex);
  });
}
