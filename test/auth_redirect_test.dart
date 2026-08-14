import 'package:firstvue/auth/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-out users are limited to public auth routes', () {
    expect(isPublicAuthRoute('/signin'), isTrue);
    expect(isPublicAuthRoute('/signup'), isTrue);
    expect(isPublicAuthRoute('/forgot-password'), isTrue);
    expect(isPublicAuthRoute('/reset-password'), isTrue);
    expect(isPublicAuthRoute('/auth/callback'), isTrue);
    expect(isPublicAuthRoute('/auth/confirm'), isTrue);
    expect(isPublicAuthRoute('/terms'), isTrue);
    expect(isPublicAuthRoute('/privacy'), isTrue);

    expect(shouldRedirectSignedOutToSignIn('/settings'), isTrue);
    expect(shouldRedirectSignedOutToSignIn('/profile'), isTrue);
    expect(shouldRedirectSignedOutToSignIn('/feeds'), isTrue);
    expect(shouldRedirectSignedOutToSignIn('/explore'), isTrue);
    expect(shouldRedirectSignedOutToSignIn('/messages'), isTrue);
    expect(shouldRedirectSignedOutToSignIn('/?business=abc'), isFalse);
  });

  test('signed-in users opening login are sent home', () {
    expect(shouldRedirectSignedInToHome('/signin'), isTrue);
    expect(shouldRedirectSignedInToHome('/signup'), isTrue);
    expect(shouldRedirectSignedInToHome('/forgot-password'), isTrue);
    expect(shouldRedirectSignedInToHome('/auth/confirm'), isTrue);
    expect(shouldRedirectSignedInToHome('/auth/callback'), isTrue);
    expect(shouldRedirectSignedInToHome('/reset-password'), isFalse);
    expect(shouldRedirectSignedInToHome('/'), isFalse);
    expect(shouldRedirectSignedInToHome('/settings'), isFalse);
  });

  test('vue and explore are allowed post-auth destinations', () {
    expect(sanitizeAuthRedirect('/vue'), '/vue');
    expect(sanitizeAuthRedirect('/explore'), '/explore');
    expect(sanitizeAuthRedirect('/home'), '/home');
  });

  test('sanitizeAuthRedirect blocks open redirects', () {
    expect(sanitizeAuthRedirect('https://evil.example/phish'), isNull);
    expect(sanitizeAuthRedirect('//evil.example'), isNull);
    expect(sanitizeAuthRedirect('https://example.com'), isNull);
    expect(sanitizeAuthRedirect('settings'), isNull);
    expect(sanitizeAuthRedirect('/settings'), '/settings');
    expect(sanitizeAuthRedirect('/signin'), '/signin');
    expect(sanitizeAuthRedirect('/terms'), '/terms');
    expect(sanitizeAuthRedirect('/not-a-real-app-route'), isNull);
  });

  test('approved callback url is never an arbitrary host', () {
    final url = Uri.parse(approvedAuthCallbackUrl());
    expect(url.hasScheme, isTrue);
    expect(url.path, '/auth/callback');
    expect(
      Uri.parse(approvedAuthCallbackUrl(path: '/reset-password')).path,
      '/reset-password',
    );
    expect(
      kAllowedAuthRedirectHosts.contains(url.host) ||
          url.host == 'firstvue.app',
      isTrue,
    );
  });

  test('AuthIdentifier parses email vs username', () {
    expect(
      AuthIdentifier.parse('jordan@firstvue.app').email,
      'jordan@firstvue.app',
    );
    expect(AuthIdentifier.parse('jordan@firstvue.app').username, isNull);
    expect(AuthIdentifier.parse('@kendale').username, 'kendale');
    expect(AuthIdentifier.parse('kendale_1').username, 'kendale_1');
    expect(AuthIdentifier.parse('ab').username, isNull);
    expect(AuthIdentifier.parse('not valid!').username, isNull);
  });

  test('OAuth flags default off', () {
    expect(oauthAppleEnabled(), isFalse);
    expect(oauthGoogleEnabled(), isFalse);
  });

  test('generic errors do not reveal whether an account exists', () {
    expect(kGenericAuthError.toLowerCase().contains('exist'), isFalse);
    expect(kGenericAuthError.toLowerCase().contains('email'), isFalse);
    expect(kGenericResetMessage.toLowerCase().contains('sent to'), isFalse);
  });
}
