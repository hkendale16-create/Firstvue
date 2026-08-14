import 'package:firstvue/theme/firstvue_theme.dart';
import 'package:firstvue/widgets/network_avatar.dart';
import 'package:firstvue/widgets/network_photo.dart';
import 'package:firstvue/widgets/profile_avatar_thumbnail.dart';
import 'package:firstvue/widgets/signed_media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile avatars render through NetworkAvatar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileAvatarThumbnail(
            imageUrl: 'https://example.com/avatar.jpg',
            displayName: 'Kendale',
          ),
        ),
      ),
    );
    expect(find.byType(NetworkAvatar), findsOneWidget);
    expect(find.byType(NetworkPhoto), findsOneWidget);
  });

  testWidgets('post photo thumbnails use NetworkPhoto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SignedMediaThumbnail(
            url: 'https://example.com/post.jpg',
            isVideo: false,
            width: 120,
            height: 120,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
    expect(find.byType(NetworkPhoto), findsOneWidget);
  });

  testWidgets('empty photo url shows a broken placeholder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FirstVueTheme.elegantDark,
        home: const Scaffold(body: NetworkPhoto(url: '')),
      ),
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
