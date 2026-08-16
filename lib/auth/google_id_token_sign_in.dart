import 'google_id_token_sign_in_stub.dart'
    if (dart.library.html) 'google_id_token_sign_in_web.dart' as impl;

/// Requests a Google ID token suitable for `signInWithIdToken`.
///
/// Web uses Google Identity Services (Client ID only). Other platforms return
/// null so callers fall back to `signInWithOAuth`.
Future<({String idToken, String nonce})?> requestGoogleIdToken() =>
    impl.requestGoogleIdToken();
