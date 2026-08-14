import 'dart:io';
import 'dart:ui' as ui;

import 'package:firstvue/screens/auth_screen.dart';
import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture mobile and desktop auth screenshots', (tester) async {
    Future<void> capture(Size size, String name) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: FirstVueTheme.elegantDark,
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: const RepaintBoundary(
              key: ValueKey('auth-shot'),
              child: AuthScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('auth-shot')),
      );
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1.5),
      );
      if (image == null) return;
      final byteData = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;
      final dir = Directory('/opt/cursor/artifacts/screenshots');
      dir.createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
    }

    await capture(const Size(390, 844), 'auth-mobile');
    await capture(const Size(1280, 800), 'auth-desktop');
  });
}
