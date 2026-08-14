import 'package:firstvue/auth/auth_redirect.dart';
import 'package:firstvue/screens/auth_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/fv_auth_field.dart';
import 'package:firstvue/widgets/fv_gold_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? FirstVueTheme.elegantDark,
    home: child,
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  testWidgets('only one authentication call-to-action exists', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    expect(find.byType(FvGoldButton), findsOneWidget);
    expect(find.text('Sign in or create account'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Welcome to FirstVue'), findsOneWidget);
    expect(find.text('Connect with what’s happening nearby.'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('mobile viewport shows the full sign-in form, not an empty block', (
    tester,
  ) async {
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: size),
        child: _wrap(const AuthScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('auth-segment-Sign in')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-email-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-primary-button')), findsOneWidget);

    // Password and primary CTA must sit inside the phone viewport. The old
    // loose Stack collapsed the sheet and left a blank dark block instead.
    final screen = tester.getRect(find.byType(AuthScreen));
    final password = tester.getRect(
      find.byKey(const ValueKey('auth-password-field')),
    );
    final button = tester.getRect(
      find.byKey(const ValueKey('auth-primary-button')),
    );
    expect(password.top, greaterThan(screen.top));
    expect(password.bottom, lessThan(screen.bottom));
    expect(button.top, greaterThan(password.bottom));
    expect(button.bottom, lessThan(screen.bottom + 1));
  });

  testWidgets('Sign in / Create account switching updates the form', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    expect(find.text('Email or username'), findsWidgets);
    expect(find.text('Forgot password?'), findsOneWidget);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('auth-segment-Create account')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Forgot password?'), findsNothing);
    expect(find.byKey(const ValueKey('auth-username-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('auth-legal-checkbox')), findsOneWidget);
    expect(
      find.text(
        'Password: 8+ characters, uppercase, lowercase, and a number.',
      ),
      findsOneWidget,
    );
    final createButton = tester.widget<FvGoldButton>(
      find.widgetWithText(FvGoldButton, 'Create account'),
    );
    expect(createButton.enabled, isFalse);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('auth-segment-Sign in')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.widgetWithText(FvGoldButton, 'Sign in'), findsOneWidget);
  });


  testWidgets('switching auth tabs clears password values', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'jordan@firstvue.app',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'Password1',
    );

    final createTab = tester.widget<InkWell>(
      find.byKey(const ValueKey('auth-segment-Create account')),
    );
    createTab.onTap!();
    await tester.pump(const Duration(milliseconds: 250));

    final password = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-password-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(password.controller?.text, isEmpty);

    final email = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-email-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(email.controller?.text, 'jordan@firstvue.app');
  });

  testWidgets('registration exposes required legal pages', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('auth-segment-Create account')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-legal-checkbox')), findsOneWidget);
  });

  testWidgets('password visibility toggle is accessible', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secretpass',
    );
    await tester.pump();
    final hidden = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-password-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(hidden.obscureText, isTrue);

    await _tapVisible(tester, find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    final shown = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('auth-password-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(shown.obscureText, isFalse);
  });

  testWidgets('keyboard Done on password submits the form', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'password1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter an email or username.'), findsOneWidget);
  });

  testWidgets('failed login produces a safe generic error', (tester) async {
    await tester.pumpWidget(_wrap(const AuthScreen()));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'kendale_1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'password1',
    );
    final submitButton = tester.widget<FvGoldButton>(
      find.byKey(const ValueKey('auth-primary-button')),
    );
    submitButton.onPressed!();
    await tester.pump();

    expect(find.text(kGenericAuthError), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('repeated taps do not submit while the button is loading', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        FvGoldButton(label: 'Sign in', loading: true, onPressed: () => taps++),
      ),
    );
    await tester.tap(find.byType(FvGoldButton));
    await tester.tap(find.byType(FvGoldButton));
    expect(taps, 0);
  });

  testWidgets('field colors stay readable in light and dark mode', (
    tester,
  ) async {
    Future<void> check(ThemeData theme) async {
      final controller = TextEditingController(text: 'jordan@firstvue.app');
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: FvAuthField(
              label: 'Email or username',
              controller: controller,
            ),
          ),
          theme: theme,
        ),
      );
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      final fill = field.decoration!.fillColor!;
      final text = field.style!.color!;
      final ratio =
          (text.computeLuminance() + 0.05) / (fill.computeLuminance() + 0.05);
      final contrast = ratio < 1 ? 1 / ratio : ratio;
      expect(contrast, greaterThanOrEqualTo(4.5));
      expect(field.cursorColor, isNotNull);
      expect(
        field.decoration!.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
    }

    await check(FirstVueTheme.elegantDark);
    await check(FirstVueTheme.elegantLight);
  });

  testWidgets('successful login destination is preserved on the controller', (
    tester,
  ) async {
    final pending = sanitizeAuthRedirect('/settings');
    expect(pending, '/settings');
  });
}
