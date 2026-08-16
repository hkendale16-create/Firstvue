/// Google OAuth client used for web ID-token sign-in and native flows.
///
/// Override at build time with:
/// `--dart-define=FIRSTVUE_GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com`
///
/// Must match Supabase → Authentication → Providers → Google → Client ID.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static const webClientId = String.fromEnvironment(
    'FIRSTVUE_GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '232279155211-ilegqngbve9fr34o5ajjq7396c48n877.apps.googleusercontent.com',
  );

  static bool get isConfigured => webClientId.trim().isNotEmpty;
}
