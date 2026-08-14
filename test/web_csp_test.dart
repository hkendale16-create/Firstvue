import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String csp;
  late String buildWebSh;
  late String bootstrap;
  late String indexHtml;
  late String toml;

  setUpAll(() {
    toml = File('netlify.toml').readAsStringSync();
    final match = RegExp(
      r'Content-Security-Policy\s*=\s*"([^"]+)"',
    ).firstMatch(toml);
    expect(match, isNotNull, reason: 'netlify.toml must declare a CSP header');
    csp = match!.group(1)!;
    buildWebSh = File('scripts/build-web.sh').readAsStringSync();
    bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    indexHtml = File('web/index.html').readAsStringSync();
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

  test('web bootstrap does not wait for a PWA service worker', () {
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(buildWebSh, contains('--pwa-strategy=none'));
  });

  test('index.html does not preload the legacy CanvasKit WASM', () {
    // Chromium loads canvaskit/chromium/canvaskit.wasm. Preloading the
    // legacy canvaskit/canvaskit.wasm made phones download both (~5MB).
    final preloadWasm = RegExp(
      r'''rel=["']preload["'][^>]*href=["'][^"']*canvaskit\.wasm["']'''
      r'''|href=["'][^"']*canvaskit\.wasm["'][^>]*rel=["']preload["']''',
      caseSensitive: false,
    );
    expect(preloadWasm.hasMatch(indexHtml), isFalse);
    expect(indexHtml, contains('rel="preload" href="main.dart.js"'));
  });

  test('seo-bootstrap is deferred so it does not contend with Flutter boot', () {
    expect(indexHtml, contains('seo-bootstrap.js" defer'));
  });

  test('Netlify caches CanvasKit and fonts so phones skip the 4MB redownload', () {
    expect(toml, contains('for = "/canvaskit/*"'));
    expect(toml, contains('for = "/assets/*"'));
    expect(toml, contains('max-age=604800'));
  });

  test('Netlify revalidates entry HTML/JS on every deploy', () {
    expect(toml, contains('for = "/index.html"'));
    expect(toml, contains('for = "/main.dart.js"'));
    expect(toml, contains('max-age=0, must-revalidate'));
  });

  test('bundled display fonts stay under Latin-subset size budgets', () {
    final cormorant = File('assets/fonts/CormorantGaramond-Variable.ttf');
    final space = File('assets/fonts/SpaceGrotesk-Variable.ttf');
    expect(cormorant.existsSync(), isTrue);
    expect(space.existsSync(), isTrue);
    // Full variable Cormorant was ~1.2MB; Latin subset must stay well under.
    expect(cormorant.lengthSync(), lessThan(400 * 1024));
    expect(space.lengthSync(), lessThan(120 * 1024));
  });

  test('auth hero image stays under 80KB after compression', () {
    final hero = File('assets/images/auth_hero.jpg');
    expect(hero.existsSync(), isTrue);
    expect(hero.lengthSync(), lessThan(80 * 1024));
  });

  test('web build script strips unused CanvasKit variants after compile', () {
    expect(buildWebSh, contains("name 'skwasm*'"));
    expect(buildWebSh, contains('webparagraph'));
    expect(buildWebSh, contains("name '*.symbols'"));
  });
}
