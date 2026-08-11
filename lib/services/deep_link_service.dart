import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  DeepLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;

  static String? businessIdFromUri(Uri? uri) {
    if (uri == null) return null;
    final id = uri.queryParameters['business'];
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static Future<String?> initialBusinessId() async {
    if (kIsWeb) return null;
    try {
      final uri = await _appLinks.getInitialLink();
      return businessIdFromUri(uri);
    } catch (_) {
      return null;
    }
  }

  static void listen(void Function(String businessId) onBusinessLink) {
    if (kIsWeb) return;
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      final businessId = businessIdFromUri(uri);
      if (businessId != null) onBusinessLink(businessId);
    });
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
