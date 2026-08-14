import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/media_caption_editor.dart';

void main() {
  testWidgets('caption editor keeps media visible with themed controls',
      (tester) async {
    final file = XFile.fromData(
      Uint8List.fromList(List<int>.filled(64, 7)),
      name: 'clip.mp4',
      mimeType: 'video/mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: MediaCaptionEditorScreen(
          localFile: file,
          isVideo: true,
          title: 'Caption photo',
          saveLabel: 'Done',
          allowSkip: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Caption photo'), findsOneWidget);
    expect(find.text('Caption'), findsOneWidget);
    expect(find.text('Say something about this photo…'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Video selected'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, FirstVuePalette.dark.background);
  });
}
