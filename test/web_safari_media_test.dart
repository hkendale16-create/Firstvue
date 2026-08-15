import 'package:firstvue/utils/web_safari_media.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web Safari media gates are off under flutter_test (VM)', () {
    // Widget tests run on the VM, not web — gates must stay false so native
    // keep-alive / autoplay behavior remains covered.
    expect(webAvoidStackedMediaTabs, isFalse);
    expect(webAvoidInlineVideoPreview, isFalse);
    expect(webScrollCacheExtent, isNull);
  });

  test('ScrollCacheExtent.pixels constructs for web cache helper', () {
    expect(const ScrollCacheExtent.pixels(180), isA<ScrollCacheExtent>());
  });
}
