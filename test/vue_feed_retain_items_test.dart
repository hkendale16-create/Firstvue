import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/screens/discovery_feed_screen.dart';

void main() {
  test('empty refresh keeps previous VUE mosaic', () {
    expect(
      shouldRetainVueItems(reset: true, previousCount: 12, incomingCount: 0),
      isTrue,
    );
  });

  test('successful refresh replaces mosaic', () {
    expect(
      shouldRetainVueItems(reset: true, previousCount: 12, incomingCount: 8),
      isFalse,
    );
  });

  test('first load empty still shows empty state', () {
    expect(
      shouldRetainVueItems(reset: true, previousCount: 0, incomingCount: 0),
      isFalse,
    );
  });

  test('load-more empty does not use retain path', () {
    expect(
      shouldRetainVueItems(reset: false, previousCount: 12, incomingCount: 0),
      isFalse,
    );
  });
}
