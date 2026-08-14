import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_session_controller.dart';

/// Single entry: never push a second [AuthScreen]. [AuthGate] owns the wall.
///
/// Returns true when a session exists. If the user is signed out, returns
/// false without opening another login route — the gate already shows Sign in.
Future<bool> ensureSignedIn(BuildContext context) async {
  if (!context.mounted) return false;
  final session =
      authSessionController.session ??
      Supabase.instance.client.auth.currentSession;
  return session != null;
}
