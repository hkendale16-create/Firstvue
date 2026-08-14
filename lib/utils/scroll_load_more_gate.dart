/// Prevents infinite scroll from re-firing while the viewport stays near the
/// bottom after a page load (common on short pages / Flutter web).
///
/// Call [onScroll] from a scroll listener. When it returns `true`, start one
/// load-more. The gate stays disarmed until the user scrolls away from the
/// end (or content grows enough that they are no longer near the end).
class ScrollLoadMoreGate {
  ScrollLoadMoreGate({this.thresholdPx = 480});

  final double thresholdPx;

  bool armed = true;

  /// Returns true exactly once per "approach the end" cycle.
  bool onScroll({
    required double pixels,
    required double maxScrollExtent,
    required bool canLoadMore,
  }) {
    if (!canLoadMore || maxScrollExtent <= 0) return false;
    final nearEnd = pixels >= maxScrollExtent - thresholdPx;
    if (!nearEnd) {
      armed = true;
      return false;
    }
    if (!armed) return false;
    armed = false;
    return true;
  }

  void reset() {
    armed = true;
  }
}
