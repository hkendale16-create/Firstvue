import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String function;
  late String authScreen;

  setUpAll(() {
    migration = File(
      'supabase/migrations/20260919_secure_auth_signup.sql',
    ).readAsStringSync();
    function = File(
      'supabase/functions/username-login/index.ts',
    ).readAsStringSync();
    authScreen = File('lib/screens/auth_screen.dart').readAsStringSync();
  });

  test('username email resolver is service-role only', () {
    expect(migration, contains('auth_email_for_username'));
    expect(
      migration,
      contains(
        'revoke all on function public.auth_email_for_username(text) from public',
      ),
    );
    expect(
      migration,
      contains(
        'grant execute on function public.auth_email_for_username(text) to service_role',
      ),
    );
    expect(migration, isNot(contains('grant execute on function public.auth_email_for_username(text) to anon')));
    expect(migration, isNot(contains('grant execute on function public.auth_email_for_username(text) to authenticated')));
  });

  test('signup trigger atomically records username and legal acceptance', () {
    expect(migration, contains('on_auth_user_created_firstvue'));
    expect(migration, contains('terms_accepted_at'));
    expect(migration, contains('privacy_accepted_at'));
    expect(migration, contains('when unique_violation'));
  });

  test('username login returns only refresh-session material', () {
    expect(
      function,
      anyOf(contains('"refresh_token"'), contains('refresh_token:')),
    );
    expect(function, isNot(contains('email: data')));
    expect(function, isNot(contains('console.log')));
    expect(function, contains('Cache-Control'));
    expect(function, contains('genericFailure'));
  });

  test('Flutter never queries private email columns for username login', () {
    expect(authScreen, contains("'username-login'"));
    expect(authScreen, isNot(contains("from('profiles').select")));
    expect(authScreen, isNot(contains('auth_email_for_username')));
  });

  test('auth sheet stack expands so the form owns the remaining viewport', () {
    expect(authScreen, contains('StackFit.expand'));
    expect(authScreen, contains('auth-password-field'));
    expect(authScreen, contains('auth-primary-button'));
  });

  test('client bundle contains no service-role credential', () {
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    expect(dart.toLowerCase(), isNot(contains('service_role')));
    expect(dart, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
  });

  test('production web builds enable only verified Google OAuth', () {
    final shell = File('scripts/build-web.sh').readAsStringSync();
    expect(shell, contains('FIRSTVUE_OAUTH_GOOGLE=true'));
    expect(shell, isNot(contains('FIRSTVUE_OAUTH_APPLE=true')));
  });

  test('Continue with Google is offered on Create account as well as Sign in', () {
    expect(authScreen, contains('(signIn || create) && (showApple || showGoogle)'));
    expect(authScreen, contains('Continue with Google'));
    expect(authScreen, contains('_oauthEnabled'));
  });
}
