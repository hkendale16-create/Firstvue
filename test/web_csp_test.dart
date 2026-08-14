import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String csp;
  late String buildWebSh;
  late String bootstrap;

  setUpAll(() {
    final toml = File('netlify.toml').readAsStringSync();
    final match = RegExp(
      r'Content-Security-Policy\s*=\s*"([^"]+)"',
    ).firstMatch(toml);
    expect(match, isNotNull, reason: 'netlify.toml must declare a CSP header');
    csp = match!.group(1)!;
    buildWebSh = File('scripts/build-web.sh').readAsStringSync();
    bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
  });

  test('CSP allows Flutter CanvasKit from gstatic and local WASM', () {
    expect(csp, contains("script-src 'self'"));
    expect(csp, contains("'wasm-unsafe-eval'"));
    expect(csp, contains('https://www.gstatic.com'));
    expect(csp, contains("connect-src 'self' blob:"));
    expect(csp, contains("worker-src 'self' blob:"));
  });

  test('CSP connect-src allows Flutter to fetch Supabase media over HTTPS', () {
    expect(csp, contains('connect-src'));
    expect(
      csp.contains('https:') || csp.contains('https://*.storage.supabase.co'),
      isTrue,
      reason: 'CanvasKit loads photos via fetch(); img-src https: is not enough',
    );
  });

  test('web builds ship local CanvasKit instead of the gstatic CDN', () {
    expect(buildWebSh, contains('--no-web-resources-cdn'));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
  });
}
