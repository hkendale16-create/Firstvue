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

  static String memberShareUrl(String profileId) {
    return '$webBaseUrl/?profile=$profileId';
  }

  static String newsPostShareUrl(String postId) {
    return '$webBaseUrl/?post=$postId';
  }

  static String eventShareUrl(String eventId) {
    return '$webBaseUrl/?event=$eventId';
  }

  static String inviteShareUrl(String code) {
    return '$webBaseUrl/invite/${code.trim()}';
  }

  static String? initialInviteCodeFromUri() {
    if (!kIsWeb) return null;
    return inviteCodeFromUri(Uri.base);
  }

  static String? inviteCodeFromUri(Uri? uri) {
    if (uri == null) return null;
    final query = uri.queryParameters['invite']?.trim();
    if (query != null && query.isNotEmpty) return query;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2 && segments.first.toLowerCase() == 'invite') {
      final code = segments[1].trim();
      if (code.isNotEmpty) return code;
    }
    return null;
  }

  static String? initialBusinessIdFromUri() {
    if (!kIsWeb) return null;
    final id = Uri.base.queryParameters['business'];
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static String? initialProfileIdFromUri() {
    if (!kIsWeb) return null;
    final id = Uri.base.queryParameters['profile'];
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static String? initialPostIdFromUri() {
    if (!kIsWeb) return null;
    final id = Uri.base.queryParameters['post'];
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
