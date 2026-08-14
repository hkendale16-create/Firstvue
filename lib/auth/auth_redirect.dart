import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Named routes that signed-out users may open.
const kPublicAuthRoutes = {
  '/',
  '/signin',
  '/signup',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/auth/callback',
  '/auth/confirm',
};

bool isPublicAuthRoute(String? name) {
  if (name == null || name.isEmpty) return true;
  final path = Uri.tryParse(name)?.path ?? name;
  if (kPublicAuthRoutes.contains(path)) return true;
  // Hash or query auth callbacks from Supabase.
  if (path.startsWith('/auth/')) return true;
  return false;
}

bool shouldRedirectSignedOutToSignIn(String? routeName) {
  return !isPublicAuthRoute(routeName);
}

bool shouldRedirectSignedInToHome(String? routeName) {
  final path = Uri.tryParse(routeName ?? '')?.path ?? routeName ?? '';
  return path == '/signin' ||
      path == '/signup' ||
      path == '/register' ||
      path == '/forgot-password';
}

const kAllowedPostAuthRoutes = {
  '/settings',
  '/profile',
  '/feeds',
  '/explore',
  '/messages',
  '/notifications',
};

const kAllowedAuthRedirectHosts = {
  'firstvue.app',
  'www.firstvue.app',
  'firstvapp.netlify.app',
  'localhost',
  '127.0.0.1',
};

/// Only same-origin relative paths. Blocks open redirects.
String? sanitizeAuthRedirect(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('//')) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.hasScheme) {
    final origin = Uri.tryParse(AppConfig.webBaseUrl);
    if (origin == null || uri.host != origin.host) return null;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (!path.startsWith('/')) return '/$path';
    return kAllowedPostAuthRoutes.contains(path) ? path : '/';
  }
  if (!trimmed.startsWith('/')) return null;
  if (trimmed.contains('://')) return null;
  final path = Uri.tryParse(trimmed)?.path ?? trimmed;
  if (kAllowedPostAuthRoutes.contains(path)) return path;
  if (isPublicAuthRoute(path)) return path;
  return null;
}

/// Absolute callback used for password reset and OAuth. Never an open redirect.
String approvedAuthCallbackUrl() {
  final raw = AppConfig.webBaseUrl;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'https://firstvue.app';
  }
  if (kAllowedAuthRedirectHosts.contains(uri.host)) {
    return uri.origin;
  }
  if (kIsWeb && uri.host == Uri.base.host) {
    return uri.origin;
  }
  return 'https://firstvue.app';
}

enum AuthSheetMode { signIn, createAccount, forgotPassword, recovery }

AuthSheetMode authModeFromRoute(String? name) {
  final path = Uri.tryParse(name ?? '')?.path ?? name ?? '/signin';
  return switch (path) {
    '/signup' || '/register' => AuthSheetMode.createAccount,
    '/forgot-password' => AuthSheetMode.forgotPassword,
    '/reset-password' => AuthSheetMode.recovery,
    '/auth/callback' || '/auth/confirm' => AuthSheetMode.signIn,
    _ => AuthSheetMode.signIn,
  };
}

/// Email if it looks like one; otherwise a username candidate.
class AuthIdentifier {
  const AuthIdentifier._({this.email, this.username});

  final String? email;
  final String? username;

  bool get isEmail => email != null;
  bool get isUsername => username != null;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static AuthIdentifier parse(String raw) {
    final trimmed = raw.trim();
    if (_email.hasMatch(trimmed)) {
      return AuthIdentifier._(email: trimmed.toLowerCase());
    }
    var handle = trimmed;
    while (handle.startsWith('@')) {
      handle = handle.substring(1);
    }
    handle = handle.toLowerCase();
    if (handle.length >= 3 && RegExp(r'^[a-z0-9_]+$').hasMatch(handle)) {
      return AuthIdentifier._(username: handle);
    }
    return const AuthIdentifier._();
  }
}

const kGenericAuthError =
    'Unable to sign in. Check your details and try again.';

const kGenericResetMessage =
    'If an account exists for that email, a reset link is on the way.';

bool oauthAppleEnabled() =>
    const bool.fromEnvironment('FIRSTVUE_OAUTH_APPLE', defaultValue: false);

bool oauthGoogleEnabled() =>
    const bool.fromEnvironment('FIRSTVUE_OAUTH_GOOGLE', defaultValue: false);
