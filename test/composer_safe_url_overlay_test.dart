import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/models/composer_overlay.dart';
import 'package:firstvue/utils/safe_url.dart';

void main() {
  group('SafeUrl', () {
    test('allows https and blocks dangerous schemes', () {
      expect(SafeUrl.sanitize('https://example.com/path'), isNotNull);
      expect(SafeUrl.sanitize('javascript:alert(1)'), isNull);
      expect(SafeUrl.sanitize('data:text/html,hi'), isNull);
      expect(SafeUrl.sanitize('file:///etc/passwd'), isNull);
    });

    test('allows FirstVue internal routes and blocks open redirects', () {
      expect(SafeUrl.sanitize('/business/abc'), '/business/abc');
      expect(SafeUrl.sanitize('/hashtag/atlanta'), '/hashtag/atlanta');
      expect(SafeUrl.sanitize('//evil.example'), isNull);
      expect(SafeUrl.sanitize('/not-a-real-prefix'), isNull);
    });

    test('classifies link kinds', () {
      expect(SafeUrl.classifyKind('/business/x'), 'business');
      expect(SafeUrl.classifyKind('/event/y'), 'event');
      expect(SafeUrl.classifyKind('https://example.com'), 'external');
    });
  });

  group('ComposerTextOverlay', () {
    test('round-trips json and clamps list parsing', () {
      const overlay = ComposerTextOverlay(
        id: 'a1',
        text: 'Hello #Atlanta',
        x: 0.4,
        y: 0.6,
        scale: 1.25,
        rotation: 0.1,
        styleKey: 'teal',
        fillKey: 'dark',
      );
      final encoded = ComposerTextOverlay.listToJson([overlay]);
      final decoded = ComposerTextOverlay.listFromJson(encoded);
      expect(decoded, hasLength(1));
      expect(decoded.first.text, 'Hello #Atlanta');
      expect(decoded.first.x, closeTo(0.4, 0.0001));
      expect(decoded.first.styleKey, 'teal');
      expect(ComposerTextOverlay.listFromJson(null), isEmpty);
      expect(ComposerTextOverlay.listFromJson('not-json'), isEmpty);
    });
  });
}
