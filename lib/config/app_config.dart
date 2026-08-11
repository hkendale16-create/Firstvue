import 'package:flutter/foundation.dart';

/// Web URL used for share links and deep links.
///
/// On web, defaults to the current origin. Override at build time with:
/// `--dart-define=FIRSTVUE_WEB_URL=https://your-domain.com`
class AppConfig {
  AppConfig._();

  static const _webUrlOverride = String.fromEnvironment('FIRSTVUE_WEB_URL');

  static String get webBaseUrl {
    if (_webUrlOverride.isNotEmpty) return _webUrlOverride;
    if (kIsWeb) return Uri.base.origin;
    return 'https://firstvue.app';
  }

  static String businessShareUrl(String businessId) {
    return '$webBaseUrl/?business=$businessId';
  }

  static String? initialBusinessIdFromUri() {
    if (!kIsWeb) return null;
    final id = Uri.base.queryParameters['business'];
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static String? billingResultFromUri() {
    if (!kIsWeb) return null;
    return Uri.base.queryParameters['billing'];
  }

  static String? billingPlanFromUri() {
    if (!kIsWeb) return null;
    return Uri.base.queryParameters['plan'];
  }
}
