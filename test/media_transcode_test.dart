import 'dart:typed_data';

import 'package:firstvue/services/media_transcode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('jpegBytesFromStill re-encodes a PNG as JPEG', () {
    final source = img.Image(width: 12, height: 8);
    img.fill(source, color: img.ColorRgb8(200, 40, 40));
    final png = Uint8List.fromList(img.encodePng(source));

    final jpeg = jpegBytesFromStill(png);
    expect(jpeg, isNotNull);
    expect(jpeg![0], 0xFF);
    expect(jpeg[1], 0xD8);
    expect(img.decodeJpg(jpeg), isNotNull);
  });

  test('jpegBytesFromStill returns null for non-images', () {
    expect(jpegBytesFromStill([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), isNull);
  });

  test('jpegFileName swaps the extension', () {
    expect(jpegFileName('scaled_IMG_0917.png'), 'scaled_IMG_0917.jpg');
    expect(jpegFileName('blob'), 'blob.jpg');
  });
}
