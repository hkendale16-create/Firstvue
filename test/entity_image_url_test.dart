import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/entity_image_url.dart';

void main() {
  group('EntityImageUrl', () {
    test('looksLikeStoragePath distinguishes paths from urls', () {
      expect(
        EntityImageUrl.looksLikeStoragePath('user/community-avatars/a.jpg'),
        isTrue,
      );
      expect(
        EntityImageUrl.looksLikeStoragePath(
          'https://example.supabase.co/storage/v1/object/sign/profile-media/x',
        ),
        isFalse,
      );
      expect(EntityImageUrl.looksLikeStoragePath(null), isFalse);
      expect(EntityImageUrl.looksLikeStoragePath(''), isFalse);
      expect(EntityImageUrl.looksLikeStoragePath('no-slash'), isFalse);
    });

    test('extractProfileMediaPath returns storage paths as-is', () {
      expect(
        EntityImageUrl.extractProfileMediaPath('abc/community-avatars/x.png'),
        'abc/community-avatars/x.png',
      );
    });

    test('extractProfileMediaPath pulls path from signed/public urls', () {
      const signed =
          'https://xyz.supabase.co/storage/v1/object/sign/profile-media/'
          'user123/community-avatars/photo.jpg?token=abc';
      expect(
        EntityImageUrl.extractProfileMediaPath(signed),
        'user123/community-avatars/photo.jpg',
      );

      const publicUrl =
          'https://xyz.supabase.co/storage/v1/object/public/profile-media/'
          'user123%2Fhubs%2Fcover.png';
      expect(
        EntityImageUrl.extractProfileMediaPath(publicUrl),
        'user123/hubs/cover.png',
      );
    });

    test('extractProfileMediaPath returns null for unrelated urls', () {
      expect(
        EntityImageUrl.extractProfileMediaPath('https://cdn.example.com/a.jpg'),
        isNull,
      );
      expect(EntityImageUrl.extractProfileMediaPath(null), isNull);
      expect(EntityImageUrl.extractProfileMediaPath(''), isNull);
    });
  });
}
