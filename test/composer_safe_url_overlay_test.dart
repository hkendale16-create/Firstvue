import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/models/composer_overlay.dart';
import 'package:firstvue/utils/safe_url.dart';
import 'package:firstvue/widgets/story_overlay_canvas.dart';

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

    test('blocks javascript mixed-case and empty values', () {
      expect(SafeUrl.sanitize('JavaScript:alert(1)'), isNull);
      expect(SafeUrl.sanitize('   '), isNull);
      expect(SafeUrl.sanitize('http://ok.example'), isNotNull);
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

  group('StoryOverlaySafeArea', () {
    test('keeps text below the owner chrome and above the reply bar', () {
      expect(StoryOverlaySafeArea.inset.top, 72);
      expect(StoryOverlaySafeArea.inset.bottom, 120);
      expect(StoryOverlaySafeArea.inset.left, 16);
    });

    testWidgets('draws a non-interactive frame while editing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 270,
            height: 480,
            child: StoryOverlayCanvas(
              overlays: const [],
              selectedId: null,
              onSelect: (_) {},
              onChanged: (_) {},
              showSafeAreaGuide: true,
            ),
          ),
        ),
      );

      expect(find.byType(IgnorePointer), findsWidgets);
    });

    test('composer shows the guide until Preview', () {
      final src =
          File('lib/screens/story_composer_screen.dart').readAsStringSync();
      expect(src, contains('showSafeAreaGuide: !_previewMode'));
    });
  });
}
