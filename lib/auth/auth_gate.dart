import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../screens/auth_screen.dart';
import '../screens/legal_policy_screen.dart';
import '../services/deep_link_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_emblem.dart';
import '../widgets/firstvue_settings_drawer.dart';
import 'auth_redirect.dart';
import 'auth_session_controller.dart';

/// Waits for the first Supabase session event, then shows Sign in or Home.
///
/// Signed-out users never see [FirstVueHome] (bottom nav / Settings).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.controller, this.signedInHome});

  final AuthSessionController? controller;

  /// Override for tests so signed-in UI does not mount the full app shell.
  @visibleForTesting
  final Widget? signedInHome;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthSessionController get _auth => widget.controller ?? authSessionController;
  bool _capturedUnsignedDestination = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _auth.start();
    if (!mounted) return;
    if (!_auth.isSignedIn) {
      _auth.rememberDeepLink(await DeepLinkService.initialTarget());
    }
  }

  void _captureUnsignedDestination() {
    if (_capturedUnsignedDestination || !kIsWeb) return;
    _capturedUnsignedDestination = true;
    final path = Uri.base.path;
    if (shouldRedirectSignedOutToSignIn(path)) {
      _auth.rememberRoute(path);
    }
    _auth.rememberDeepLink(DeepLinkService.targetFromUri(Uri.base));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        if (_auth.restoring) {
          return const AuthSplash();
        }
        if (_auth.lastEvent == AuthChangeEvent.passwordRecovery) {
          return AuthScreen(
            key: const ValueKey('auth-recovery'),
            initialMode: AuthSheetMode.recovery,
            allowBack: false,
          );
        }
        if (!_auth.isSignedIn) {
          _captureUnsignedDestination();
          return AuthScreen(
            key: const ValueKey('auth-wall'),
            initialMode: _modeForSignedOut(),
            allowBack: false,
          );
        }
        return widget.signedInHome ?? const FirstVueHome();
      },
    );
  }

  AuthSheetMode _modeForSignedOut() {
    if (!kIsWeb) return AuthSheetMode.signIn;
    return authModeFromRoute(Uri.base.path);
  }
}

/// Branded hold while the first auth event is unresolved.
class AuthSplash extends StatelessWidget {
  const AuthSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFF0B1020),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FirstVueEmblem(size: 72),
            SizedBox(height: 20),
            Text(
              'FirstVue',
              style: TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 28,
                color: FirstVueColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FirstVueColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Named-route helper used by [MaterialApp.onGenerateRoute].
Route<dynamic> generateAuthAwareRoute(
  RouteSettings settings, {
  AuthSessionController? controller,
}) {
  final auth = controller ?? authSessionController;
  final name = settings.name ?? '/';
  final path = Uri.tryParse(name)?.path ?? name;
  final signedIn = auth.isSignedIn;
  final recovering = auth.lastEvent == AuthChangeEvent.passwordRecovery;

  if (isLegalRoute(path)) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => LegalPolicyScreen(
        type: path == '/privacy'
            ? LegalPolicyType.privacy
            : LegalPolicyType.terms,
      ),
    );
  }

  if (path == '/' || path.isEmpty) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => AuthGate(controller: auth),
    );
  }

  if (!signedIn || recovering) {
    if (isPublicAuthRoute(path) || shouldRedirectSignedOutToSignIn(path)) {
      if (shouldRedirectSignedOutToSignIn(path)) {
        auth.rememberRoute(path);
      }
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/signin'),
        builder: (_) => AuthScreen(
          initialMode: recovering
              ? AuthSheetMode.recovery
              : authModeFromRoute(path),
          allowBack: false,
        ),
      );
    }
  }

  if (signedIn && !recovering && shouldRedirectSignedInToHome(path)) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => const FirstVueHome(),
    );
  }

  if (path == '/settings' || path == SettingsShellScreen.routeName) {
    if (!signedIn) {
      auth.rememberRoute('/settings');
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/signin'),
        builder: (_) => const AuthScreen(allowBack: false),
      );
    }
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const SettingsShellScreen(),
    );
  }

  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) =>
        signedIn ? const FirstVueHome() : const AuthScreen(allowBack: false),
  );
}
