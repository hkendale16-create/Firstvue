import 'web_seo_stub.dart'
    if (dart.library.html) 'web_seo_web.dart' as impl;

class WebSeoService {
  WebSeoService._();

  static void update({
    required String title,
    String? description,
    String? imageUrl,
    String? canonicalUrl,
  }) {
    impl.updateWebSeo(
      title: title,
      description: description,
      imageUrl: imageUrl,
      canonicalUrl: canonicalUrl,
    );
  }

  static void reset() {
    impl.updateWebSeo(
      title: 'FirstVue — Discover, verify, and choose trusted local pros',
      description:
          'FirstVue helps you discover, verify, and choose trusted beauty and service businesses.',
    );
  }
}
