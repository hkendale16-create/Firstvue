/// Shared TTL constants for device caches (no service imports).
class CacheTtls {
  CacheTtls._();

  static const profile = Duration(minutes: 30);
  static const business = Duration(minutes: 10);
  static const entityDetails = Duration(minutes: 15);
  static const exploreSection = Duration(minutes: 5);
  static const feedPage = Duration(minutes: 3);
  static const viewedPost = Duration(minutes: 30);
}
