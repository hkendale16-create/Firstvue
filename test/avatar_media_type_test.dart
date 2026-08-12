import 'package:firstvue/services/media_type_helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('avatar replacement media types', () {
    test('detects image and video mime families for avatar replace cycles', () {
      expect(mediaTypeForFile(XFile('avatar.jpg')), 'image');
      expect(mediaTypeForFile(XFile('avatar.PNG')), 'image');
      expect(mediaTypeForFile(XFile('avatar.webp')), 'image');
      expect(mediaTypeForFile(XFile('avatar.mp4')), 'video');
      expect(mediaTypeForFile(XFile('avatar.mov')), 'video');
      expect(mediaTypeForFile(XFile('avatar.webm')), 'video');
    });
  });
}
