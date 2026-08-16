import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:web/web.dart' as web;

import '../config/google_auth_config.dart';

/// Obtains a Google ID token via Google Identity Services (no client secret).
///
/// Uses the Sign in with Google button in a lightweight overlay so it works on
/// mobile Safari where One Tap / FedCM is often blocked. Returns null when the
/// user cancels so the caller can fall back to OAuth redirect.
Future<({String idToken, String nonce})?> requestGoogleIdToken() async {
  if (!GoogleAuthConfig.isConfigured) return null;

  try {
    await _ensureGisLoaded();
  } catch (_) {
    return null;
  }

  final rawNonce = _randomNonce();
  final hashedNonce = await _sha256Hex(rawNonce);
  final completer = Completer<({String idToken, String nonce})?>();

  void finish(({String idToken, String nonce})? value) {
    _removeOverlay();
    if (!completer.isCompleted) completer.complete(value);
  }

  final callback = (JSObject response) {
    final credential = response.getProperty('credential'.toJS);
    final token = credential == null ? null : (credential as JSString).toDart;
    if (token == null || token.isEmpty) {
      finish(null);
      return;
    }
    finish((idToken: token, nonce: rawNonce));
  }.toJS;

  try {
    final google = web.window.getProperty('google'.toJS) as JSObject?;
    final accounts = google?.getProperty('accounts'.toJS) as JSObject?;
    final id = accounts?.getProperty('id'.toJS) as JSObject?;
    if (id == null) return null;

    final config = JSObject()
      ..setProperty('client_id'.toJS, GoogleAuthConfig.webClientId.toJS)
      ..setProperty('callback'.toJS, callback)
      ..setProperty('nonce'.toJS, hashedNonce.toJS)
      ..setProperty('auto_select'.toJS, false.toJS)
      ..setProperty('cancel_on_tap_outside'.toJS, false.toJS)
      ..setProperty('use_fedcm_for_prompt'.toJS, true.toJS);
    id.callMethod('initialize'.toJS, config);

    final host = _mountOverlay(onCancel: () => finish(null));
    final buttonOpts = JSObject()
      ..setProperty('type'.toJS, 'standard'.toJS)
      ..setProperty('theme'.toJS, 'outline'.toJS)
      ..setProperty('size'.toJS, 'large'.toJS)
      ..setProperty('text'.toJS, 'continue_with'.toJS)
      ..setProperty('shape'.toJS, 'pill'.toJS)
      ..setProperty('width'.toJS, 280.toJS);
    id.callMethod('renderButton'.toJS, host, buttonOpts);

    // Also try One Tap; if it succeeds the overlay still closes via callback.
    try {
      id.callMethod('prompt'.toJS);
    } catch (_) {
      // Button overlay remains the primary path.
    }
  } catch (_) {
    finish(null);
  }

  return completer.future.timeout(
    const Duration(minutes: 3),
    onTimeout: () {
      _removeOverlay();
      return null;
    },
  );
}

web.HTMLElement? _overlayRoot;

web.HTMLElement _mountOverlay({required void Function() onCancel}) {
  _removeOverlay();

  final overlay = web.document.createElement('div') as web.HTMLDivElement;
  overlay.id = 'fv-google-signin-overlay';
  overlay.style.cssText = [
    'position:fixed',
    'inset:0',
    'z-index:2147483646',
    'display:flex',
    'align-items:center',
    'justify-content:center',
    'background:rgba(8,13,27,0.72)',
    'padding:24px',
  ].join(';');

  final card = web.document.createElement('div') as web.HTMLDivElement;
  card.style.cssText = [
    'background:#111726',
    'border:1px solid #293148',
    'border-radius:20px',
    'padding:24px 20px 18px',
    'max-width:340px',
    'width:100%',
    'text-align:center',
    'box-shadow:0 18px 48px rgba(0,0,0,0.45)',
    'font-family:system-ui,sans-serif',
  ].join(';');

  final title = web.document.createElement('div') as web.HTMLDivElement;
  title.textContent = 'Continue with Google';
  title.style.cssText =
      'color:#D8B56A;font-size:18px;font-weight:600;margin-bottom:8px';

  final body = web.document.createElement('div') as web.HTMLDivElement;
  body.textContent = 'Choose your Google account to finish signing in.';
  body.style.cssText =
      'color:rgba(255,255,255,0.72);font-size:14px;line-height:1.4;margin-bottom:18px';

  final host = web.document.createElement('div') as web.HTMLDivElement;
  host.style.cssText =
      'display:flex;justify-content:center;min-height:44px;margin-bottom:12px';

  final cancel = web.document.createElement('button') as web.HTMLButtonElement;
  cancel.textContent = 'Cancel';
  cancel.type = 'button';
  cancel.style.cssText = [
    'background:transparent',
    'border:0',
    'color:rgba(255,255,255,0.55)',
    'font-size:14px',
    'padding:10px 12px',
    'cursor:pointer',
  ].join(';');
  cancel.onclick = ((web.MouseEvent _) {
    onCancel();
  }).toJS;

  card.append(title);
  card.append(body);
  card.append(host);
  card.append(cancel);
  overlay.append(card);
  web.document.body!.append(overlay);

  _overlayRoot = overlay;
  return host;
}

void _removeOverlay() {
  _overlayRoot?.remove();
  _overlayRoot = null;
}

bool _gisLoading = false;
Completer<void>? _gisReady;

Future<void> _ensureGisLoaded() async {
  if (_gisReady != null) return _gisReady!.future;
  _gisReady = Completer<void>();
  if (_gisLoading) return _gisReady!.future;
  _gisLoading = true;

  try {
    if (_hasGis()) {
      _gisReady!.complete();
      return;
    }

    final script = web.HTMLScriptElement()
      ..src = 'https://accounts.google.com/gsi/client'
      ..async = true;
    final done = Completer<void>();
    script.onload = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    script.onerror = ((web.Event _) {
      if (!done.isCompleted) {
        done.completeError(
          StateError('Failed to load Google Identity Services'),
        );
      }
    }).toJS;
    web.document.head!.append(script);
    await done.future.timeout(const Duration(seconds: 20));
    if (!_hasGis()) {
      throw StateError('Google Identity Services unavailable');
    }
    _gisReady!.complete();
  } catch (e, st) {
    final c = _gisReady!;
    _gisReady = null;
    _gisLoading = false;
    c.completeError(e, st);
    rethrow;
  }
}

bool _hasGis() {
  final google = web.window.getProperty('google'.toJS) as JSObject?;
  final accounts = google?.getProperty('accounts'.toJS) as JSObject?;
  final id = accounts?.getProperty('id'.toJS);
  return id != null;
}

String _randomNonce() {
  final random = Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  return base64UrlEncode(bytes).replaceAll('=', '');
}

Future<String> _sha256Hex(String value) async {
  final hash = await Sha256().hash(utf8.encode(value));
  return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
