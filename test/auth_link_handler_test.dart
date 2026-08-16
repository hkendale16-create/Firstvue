import 'package:firstvue/auth/auth_link_handler.dart';
import 'package:firstvue/auth/auth_redirect.dart';
import 'package:firstvue/screens/auth_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(AuthLinkHandler.debugReset);

  test('oauthErrorFromUri maps provider exchange failures', () {
    final uri = Uri.parse(
      'https://firstvapp.netlify.app/auth/callback'
      '?error=server_error'
      '&error_description=Unable+to+exchange+external+code',
    );
    expect(AuthLinkHandler.oauthErrorFromUri(uri), kOauthCallbackError);
  });

  test('oauthErrorFromUri maps access_denied to a cancel message', () {
    final uri = Uri.parse(
      'https://firstvapp.netlify.app/auth/callback?error=access_denied',
    );
    expect(
      AuthLinkHandler.oauthErrorFromUri(uri),
      'Google sign-in was cancelled. You can try again or use email.',
    );
  });

  test('oauthErrorFromUri ignores successful code callbacks', () {
    final uri = Uri.parse(
      'https://firstvapp.netlify.app/auth/callback?code=abc123',
    );
    expect(AuthLinkHandler.oauthErrorFromUri(uri), isNull);
  });

  testWidgets('AuthScreen shows pending OAuth callback error', (tester) async {
    AuthLinkHandler.debugSetPendingError(kOauthCallbackError);
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const AuthScreen(),
      ),
    );
    await tester.pump();

    expect(find.text(kOauthCallbackError), findsOneWidget);
    expect(AuthLinkHandler.takePendingError(), isNull);
  });
}
