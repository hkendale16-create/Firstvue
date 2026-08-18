import 'dart:typed_data';

import 'package:firstvue/services/media_variants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('pathFor builds sibling variant paths', () {
    expect(
      MediaVariants.pathFor('user/abc_photo.jpg', MediaVariant.thumb),
      'user/abc_photo__v_thumb.jpg',
    );
    expect(
      MediaVariants.pathFor('user/abc_photo.jpg', MediaVariant.feed),
      'user/abc_photo__v_feed.jpg',
    );
    expect(
      MediaVariants.pathFor('user/abc_photo.jpg', MediaVariant.full),
      'user/abc_photo.jpg',
    );
  });

  test('pathFor leaves remote demo URLs unchanged', () {
    const remote = 'https://picsum.photos/seed/fvdemo_biz_1/1000/1200';
    expect(MediaVariants.isRemoteUrl(remote), isTrue);
    expect(MediaVariants.pathFor(remote, MediaVariant.thumb), remote);
    expect(
      MediaVariants.candidatePaths(remote, preferred: MediaVariant.thumb),
      [remote],
    );
  });

  test('candidatePaths tries full object before derived variants', () {
    expect(
      MediaVariants.candidatePaths(
        'user/photo.jpg',
        preferred: MediaVariant.feed,
        explicitThumbnailPath: 'user/photo_thumb.jpg',
      ),
      [
        'user/photo_thumb.jpg',
        'user/photo.jpg',
        'user/photo__v_feed.jpg',
        'user/photo__v_thumb.jpg',
      ],
    );
  });

  test('prepare encodes full/feed/thumb stills', () {
    final source = img.Image(width: 1200, height: 800);
    img.fill(source, color: img.ColorRgb8(20, 120, 200));
    final png = Uint8List.fromList(img.encodePng(source));

    final prepared = MediaVariants.prepare(
      png,
      originalName: 'shot.png',
      includeAvatarSizes: true,
    );
    expect(prepared, isNotNull);
    expect(prepared!.fileName, 'shot.jpg');
    expect(prepared.contentType, 'image/jpeg');
    expect(prepared.fullBytes.first, 0xFF);
    expect(prepared.thumbBytes.first, 0xFF);
    expect(prepared.feedBytes.first, 0xFF);
    expect(prepared.avatar64Bytes, isNotNull);
    expect(prepared.avatar128Bytes, isNotNull);

    final full = img.decodeJpg(prepared.fullBytes)!;
    final thumb = img.decodeJpg(prepared.thumbBytes)!;
    expect(full.width, lessThanOrEqualTo(1600));
    expect(thumb.width, lessThanOrEqualTo(480));
    expect(thumb.width, lessThan(full.width));
  });
}
