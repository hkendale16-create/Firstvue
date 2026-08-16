import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_link_handler_stub.dart'
    if (dart.library.html) 'auth_link_handler_web.dart' as url_cleaner;
import 'auth_redirect.dart';

/// Completes email-confirm / OAuth callback links once, then clears the URL.
///
/// Leaving `?code=` on `/auth/confirm` caused Safari to remount Flutter and
/// re-process the one-time code until WebKit showed "A problem repeatedly
/// occurred".
class AuthLinkHandler {
  AuthLinkHandler._();

  static bool _handled = false;
  static String? _pendingError;

  static bool get isAuthCallbackPath {
    if (!kIsWeb) return false;
    final path = Uri.base.path;
    return path == '/auth/confirm' ||
        path == '/auth/callback' ||
        path == '/reset-password';
  }

  /// OAuth / magic-link failure message captured from the callback URL.
  ///
  /// Consumed once by [AuthScreen] so the user sees why sign-in stopped
  /// instead of silently returning to an empty form.
  static String? takePendingError() {
    final error = _pendingError;
    _pendingError = null;
    return error;
  }

  /// Exchange the one-time code (if present) and strip auth params from the URL.
  static Future<void> completeIfNeeded() async {
    if (!kIsWeb || _handled) return;
    if (!isAuthCallbackPath && !_hasAuthParams(Uri.base)) return;
    _handled = true;

    final uri = Uri.base;
    final oauthError = oauthErrorFromUri(uri);
    try {
      if (oauthError != null) {
        _pendingError = oauthError;
      } else if (_hasAuthParams(uri) || uri.queryParameters.containsKey('code')) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } catch (_) {
      // Code already used, invalid, or provider exchange failed server-side.
      _pendingError ??= kOauthCallbackError;
    } finally {
      url_cleaner.replaceAuthUrl(
        uri.path == '/reset-password' ? '/reset-password' : '/',
      );
    }
  }

  /// Maps Supabase/Google callback error params to a safe user-facing message.
  @visibleForTesting
  static String? oauthErrorFromUri(Uri uri) {
    final q = uri.queryParameters;
    final error = (q['error'] ?? '').trim();
    if (error.isEmpty) {
      final frag = uri.fragment;
      if (frag.isEmpty) return null;
      final fragParams = Uri.splitQueryString(frag);
      final fragError = (fragParams['error'] ?? '').trim();
      if (fragError.isEmpty) return null;
      return _messageForOauthError(
        fragError,
        fragParams['error_description'],
      );
    }
    return _messageForOauthError(error, q['error_description']);
  }

  static String _messageForOauthError(String error, String? description) {
    final desc = (description ?? '').toLowerCase();
    if (desc.contains('exchange') ||
        desc.contains('invalid_client') ||
        desc.contains('client secret') ||
        error == 'server_error') {
      return kOauthCallbackError;
    }
    if (error == 'access_denied') {
      return 'Google sign-in was cancelled. You can try again or use email.';
    }
    return kOauthCallbackError;
  }

  static bool _hasAuthParams(Uri uri) {
    final q = uri.queryParameters;
    if (q.containsKey('code') ||
        q.containsKey('token_hash') ||
        q.containsKey('type') ||
        q.containsKey('access_token') ||
        q.containsKey('refresh_token') ||
        q.containsKey('error') ||
        q.containsKey('error_description')) {
      return true;
    }
    final frag = uri.fragment;
    return frag.contains('access_token') || frag.contains('error');
  }

  /// Test-only: reset one-shot state between widget tests.
  @visibleForTesting
  static void debugReset() {
    _handled = false;
    _pendingError = null;
  }

  /// Test-only: seed a pending callback error without a browser URL.
  @visibleForTesting
  static void debugSetPendingError(String? message) {
    _pendingError = message;
  }
}
