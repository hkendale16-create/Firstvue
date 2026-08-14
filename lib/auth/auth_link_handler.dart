import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_link_handler_stub.dart'
    if (dart.library.html) 'auth_link_handler_web.dart' as url_cleaner;

/// Completes email-confirm / OAuth callback links once, then clears the URL.
///
/// Leaving `?code=` on `/auth/confirm` caused Safari to remount Flutter and
/// re-process the one-time code until WebKit showed "A problem repeatedly
/// occurred".
class AuthLinkHandler {
  AuthLinkHandler._();

  static bool _handled = false;

  static bool get isAuthCallbackPath {
    if (!kIsWeb) return false;
    final path = Uri.base.path;
    return path == '/auth/confirm' ||
        path == '/auth/callback' ||
        path == '/reset-password';
  }

  /// Exchange the one-time code (if present) and strip auth params from the URL.
  static Future<void> completeIfNeeded() async {
    if (!kIsWeb || _handled) return;
    if (!isAuthCallbackPath && !_hasAuthParams(Uri.base)) return;
    _handled = true;

    final uri = Uri.base;
    try {
      if (_hasAuthParams(uri) || uri.queryParameters.containsKey('code')) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      }
    } catch (_) {
      // Code already used or invalid — still clear the URL so we do not loop.
    } finally {
      url_cleaner.replaceAuthUrl(
        uri.path == '/reset-password' ? '/reset-password' : '/',
      );
    }
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
}
