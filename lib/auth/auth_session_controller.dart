import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/deep_link_service.dart';
import 'auth_local_state.dart';
import 'auth_redirect.dart';

/// App-wide auth session. Waits for Supabase restoration before exposing UI.
class AuthSessionController extends ChangeNotifier {
  AuthSessionController({this._auth});

  AuthSessionController._test() : _auth = null;

  /// Test controller that does not subscribe to Supabase.
  @visibleForTesting
  factory AuthSessionController.test({
    bool restoring = false,
    Session? session,
    AuthChangeEvent? lastEvent,
  }) {
    final controller = AuthSessionController._test();
    controller
      .._restoring = restoring
      .._session = session
      .._lastEvent = lastEvent
      .._started = true;
    return controller;
  }

  GoTrueClient? _auth;
  StreamSubscription<AuthState>? _sub;
  Session? _session;
  bool _restoring = true;
  AuthChangeEvent? _lastEvent;
  DeepLinkTarget? _pendingDeepLink;
  String? _pendingRoute;
  bool _started = false;

  /// Pop stacked routes (Settings, etc.) after sign-out.
  VoidCallback? onSessionCleared;

  GoTrueClient get auth => _auth ?? Supabase.instance.client.auth;

  Session? get session => _session;
  bool get restoring => _restoring;
  bool get isSignedIn => _session != null;
  AuthChangeEvent? get lastEvent => _lastEvent;
  DeepLinkTarget? get pendingDeepLink => _pendingDeepLink;
  String? get pendingRoute => _pendingRoute;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _session = auth.currentSession;
    final firstEvent = Completer<void>();
    _sub = auth.onAuthStateChange.listen((data) {
      _onAuth(data);
      if (!firstEvent.isCompleted) firstEvent.complete();
    });
    try {
      await firstEvent.future.timeout(const Duration(milliseconds: 1200));
    } catch (_) {
      _session = auth.currentSession;
    }
    _restoring = false;
    notifyListeners();
  }

  void _onAuth(AuthState data) {
    final wasSignedIn = _session != null;
    _session = data.session;
    _lastEvent = data.event;
    _restoring = false;
    final signedOut =
        data.event == AuthChangeEvent.signedOut ||
        (data.session == null && wasSignedIn);
    if (signedOut) {
      unawaited(AuthLocalState.clearProtected());
      _pendingDeepLink = null;
      _pendingRoute = null;
      onSessionCleared?.call();
    } else if (data.event == AuthChangeEvent.signedIn && data.session != null) {
      // Password sign-in also calls ensure_user_profile; OAuth only lands here.
      unawaited(_ensureProfile(data.session!.user));
    }
    notifyListeners();
  }

  Future<void> _ensureProfile(User user) async {
    final displayName = user.email?.split('@').first;
    try {
      await Supabase.instance.client.rpc(
        'ensure_user_profile',
        params: {'display_name': displayName},
      );
    } catch (_) {
      // Retried by signed-in feature services when needed.
    }
  }

  void rememberDeepLink(DeepLinkTarget? target) {
    if (target == null) return;
    _pendingDeepLink = target;
  }

  void rememberRoute(String? route) {
    _pendingRoute = sanitizeAuthRedirect(route);
  }

  DeepLinkTarget? takePendingDeepLink() {
    final target = _pendingDeepLink;
    _pendingDeepLink = null;
    return target;
  }

  String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  Future<void> signOut() async {
    await AuthLocalState.clearProtected();
    _pendingDeepLink = null;
    _pendingRoute = null;
    try {
      await auth.signOut();
    } catch (_) {
      _session = null;
      _lastEvent = AuthChangeEvent.signedOut;
      notifyListeners();
      onSessionCleared?.call();
    }
  }

  /// Simulate an auth event in widget tests without a live GoTrue client.
  @visibleForTesting
  void debugEmit({
    Session? session,
    AuthChangeEvent event = AuthChangeEvent.signedIn,
  }) {
    _session = session;
    _lastEvent = event;
    _restoring = false;
    if (session == null || event == AuthChangeEvent.signedOut) {
      unawaited(AuthLocalState.clearProtected());
      _pendingDeepLink = null;
      _pendingRoute = null;
      onSessionCleared?.call();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final authSessionController = AuthSessionController();
