import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session_controller.dart';

/// Single entry: never push a second auth sheet. [AuthGate] owns the wall.
///
/// Returns true when a session exists. If signed out, remembers [rememberRoute]
/// (when provided), pops nested routes so the gate shows Sign in, and returns
/// false — same pattern as Instagram requiring login before any app action.
Future<bool> ensureSignedIn(
  BuildContext context, {
  String? rememberRoute,
}) async {
  if (!context.mounted) return false;
  final session =
      authSessionController.session ??
      Supabase.instance.client.auth.currentSession;
  if (session != null) return true;

  if (rememberRoute != null && rememberRoute.isNotEmpty) {
    authSessionController.rememberRoute(rememberRoute);
  }

  // Drop stacked sheets/routes so AuthGate's signed-out AuthScreen is visible.
  final nav = Navigator.maybeOf(context, rootNavigator: true);
  if (nav != null && nav.canPop()) {
    nav.popUntil((route) => route.isFirst);
  }

  return false;
}
