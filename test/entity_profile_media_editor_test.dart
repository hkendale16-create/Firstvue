import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/entity_profile_media_editor.dart';

void main() {
  testWidgets('entity photo editor shows add and remove actions', (
    tester,
  ) async {
    var changeAvatar = 0;
    var removeAvatar = 0;
    var changeCover = 0;
    var removeCover = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Scaffold(
          body: EntityProfileMediaEditor(
            avatarUrl: 'https://example.com/a.jpg',
            coverUrl: 'https://example.com/c.jpg',
            onChangeAvatar: () => changeAvatar++,
            onRemoveAvatar: () => removeAvatar++,
            onChangeCover: () => changeCover++,
            onRemoveCover: () => removeCover++,
          ),
        ),
      ),
    );

    expect(find.text('PROFILE PHOTOS'), findsOneWidget);
    expect(find.text('Remove cover'), findsOneWidget);
    expect(find.text('Remove profile photo'), findsOneWidget);

    await tester.tap(find.text('Remove cover'));
    await tester.pump();
    expect(removeCover, 1);

    await tester.tap(find.text('Remove profile photo'));
    await tester.pump();
    expect(removeAvatar, 1);

    await tester.tap(find.text('Profile photo'));
    await tester.pump();
    expect(changeAvatar, 1);
  });

  testWidgets('entity photo action sheet offers add when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEntityPhotoActionSheet(
                context,
                photoLabel: 'profile photo',
                hasPhoto: false,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Add profile photo'), findsOneWidget);
    expect(find.text('Remove profile photo'), findsNothing);
  });
}
