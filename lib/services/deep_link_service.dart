import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkTarget {
  final String type;
  final String id;

  const DeepLinkTarget({required this.type, required this.id});
}

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

  static String? profileIdFromUri(Uri? uri) {
    if (uri == null) return null;
    final id = uri.queryParameters['profile'];
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static String? postIdFromUri(Uri? uri) {
    if (uri == null) return null;
    final id = uri.queryParameters['post'];
    if (id == null || id.trim().isEmpty) return null;
    return id.trim();
  }

  static DeepLinkTarget? targetFromUri(Uri? uri) {
    if (uri == null) return null;

    final businessId = businessIdFromUri(uri);
    if (businessId != null) {
      return DeepLinkTarget(type: 'business', id: businessId);
    }

    final profileId = profileIdFromUri(uri);
    if (profileId != null) {
      return DeepLinkTarget(type: 'profile', id: profileId);
    }

    final postId = postIdFromUri(uri);
    if (postId != null) {
      return DeepLinkTarget(type: 'post', id: postId);
    }

    return null;
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

  static Future<DeepLinkTarget?> initialTarget() async {
    if (kIsWeb) {
      return targetFromUri(Uri.base);
    }
    try {
      final uri = await _appLinks.getInitialLink();
      return targetFromUri(uri);
    } catch (_) {
      return null;
    }
  }

  static void listen(void Function(DeepLinkTarget target) onLink) {
    if (kIsWeb) return;
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      final target = targetFromUri(uri);
      if (target != null) onLink(target);
    });
  }

  static void listenBusiness(void Function(String businessId) onBusinessLink) {
    listen((target) {
      if (target.type == 'business') onBusinessLink(target.id);
    });
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
