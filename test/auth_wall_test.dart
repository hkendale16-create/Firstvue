import 'package:firstvue/auth/auth_gate.dart';
import 'package:firstvue/auth/auth_session_controller.dart';
import 'package:firstvue/main.dart';
import 'package:firstvue/screens/auth_screen.dart';
import 'package:firstvue/widgets/firstvue_settings_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Widget _app({required AuthSessionController controller, Widget? signedInHome}) {
  return MaterialApp(
    home: AuthGate(controller: controller, signedInHome: signedInHome),
  );
}

void main() {
  testWidgets('session restoration shows branded splash, not protected UI', (
    tester,
  ) async {
    final auth = AuthSessionController.test(restoring: true);
    await tester.pumpWidget(
      _app(controller: auth, signedInHome: const Text('PROTECTED_HOME')),
    );

    expect(find.byType(AuthSplash), findsOneWidget);
    expect(find.text('PROTECTED_HOME'), findsNothing);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(find.byType(AuthScreen), findsNothing);
    expect(find.text('FirstVue'), findsWidgets);
  });

  testWidgets('signed-out user opening Settings is redirected to Sign in', (
    tester,
  ) async {
    final auth = AuthSessionController.test();
    final route = generateAuthAwareRoute(
      const RouteSettings(name: '/settings'),
      controller: auth,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              (route as MaterialPageRoute<void>).builder(context),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
    expect(find.byType(SettingsShellScreen), findsNothing);
    expect(find.text('Settings'), findsNothing);
    expect(auth.pendingRoute, '/settings');
  });

  testWidgets('signed-out user opening a protected deep link is redirected', (
    tester,
  ) async {
    final auth = AuthSessionController.test();
    final route = generateAuthAwareRoute(
      const RouteSettings(name: '/messages'),
      controller: auth,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              (route as MaterialPageRoute<void>).builder(context),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('signed-in user opening Sign in is redirected to Home', (
    tester,
  ) async {
    final auth = AuthSessionController.test(session: _fakeSession());
    await tester.pumpWidget(
      _app(controller: auth, signedInHome: const Text('HOME_SHELL')),
    );
    await tester.pump();

    expect(find.text('HOME_SHELL'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);

    final route = generateAuthAwareRoute(
      const RouteSettings(name: '/signin'),
      controller: auth,
    );
    expect(route.settings.name, '/');
    expect(
      (route as MaterialPageRoute<void>).builder(
        tester.element(find.text('HOME_SHELL')),
      ),
      isA<FirstVueHome>(),
    );
  });

  testWidgets('sign-out immediately removes Settings access', (tester) async {
    final auth = AuthSessionController.test(session: _fakeSession());
    await tester.pumpWidget(
      _app(
        controller: auth,
        signedInHome: const Scaffold(body: Text('Settings')),
      ),
    );
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);

    auth.debugEmit(event: AuthChangeEvent.signedOut);
    await tester.pump();

    expect(find.text('Settings'), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
  });

  testWidgets('AuthGate signed-out UI has no bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_app(controller: AuthSessionController.test()));
    await tester.pump();
    expect(find.text('HOME'), findsNothing);
    expect(find.text('FEEDS'), findsNothing);
    expect(find.text('EXPLORE'), findsNothing);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
  });
}
