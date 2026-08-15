import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/utils/scroll_load_more_gate.dart';

void main() {
  test('ScrollLoadMoreGate fires once until scrolled away from end', () {
    final gate = ScrollLoadMoreGate(thresholdPx: 100);

    expect(
      gate.onScroll(pixels: 50, maxScrollExtent: 500, canLoadMore: true),
      isFalse,
    );
    expect(
      gate.onScroll(pixels: 420, maxScrollExtent: 500, canLoadMore: true),
      isTrue,
    );
    // Still near the end — must not re-fire (this was the feed reload loop).
    expect(
      gate.onScroll(pixels: 450, maxScrollExtent: 500, canLoadMore: true),
      isFalse,
    );
    expect(
      gate.onScroll(pixels: 490, maxScrollExtent: 500, canLoadMore: true),
      isFalse,
    );

    // Scroll away, then approach again.
    expect(
      gate.onScroll(pixels: 200, maxScrollExtent: 500, canLoadMore: true),
      isFalse,
    );
    expect(
      gate.onScroll(pixels: 430, maxScrollExtent: 500, canLoadMore: true),
      isTrue,
    );
  });

  test('ScrollLoadMoreGate respects canLoadMore', () {
    final gate = ScrollLoadMoreGate(thresholdPx: 100);
    expect(
      gate.onScroll(pixels: 450, maxScrollExtent: 500, canLoadMore: false),
      isFalse,
    );
    expect(gate.armed, isTrue);
  });
}
