/// Safe URL validation for social captions, Story links, and rich text.
///
/// Allows http(s) and FirstVue internal deep routes. Blocks dangerous schemes.
class SafeUrl {
  SafeUrl._();

  static const _blockedSchemes = {
    'javascript',
    'data',
    'vbscript',
    'file',
    'blob',
    'about',
  };

  /// Internal app path prefixes that may be stored/opened as deep links.
  static const internalRoutePrefixes = <String>[
    '/home',
    '/feeds',
    '/vue',
    '/explore',
    '/search',
    '/profile',
    '/member',
    '/business',
    '/professional',
    '/community',
    '/group',
    '/event',
    '/post',
    '/story',
    '/hashtag',
    '/settings',
    '/messages',
    '/live',
  ];

  /// Returns a sanitized absolute http(s) URL, an internal route, or null.
  static String? sanitize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > 2048) return null;

    // Internal FirstVue route (prefer over external wrappers).
    if (trimmed.startsWith('/')) {
      if (trimmed.startsWith('//')) return null; // protocol-relative
      final path = trimmed.split('?').first.split('#').first;
      final ok = internalRoutePrefixes.any(
        (prefix) => path == prefix || path.startsWith('$prefix/'),
      );
      return ok ? trimmed : null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      // Bare domain → https
      final asHttps = Uri.tryParse('https://$trimmed');
      if (asHttps == null || asHttps.host.isEmpty) return null;
      if (!_looksLikeHost(asHttps.host)) return null;
      return asHttps.toString();
    }

    final scheme = uri.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) return null;
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.isEmpty || !_looksLikeHost(uri.host)) return null;
    return uri.toString();
  }

  static bool isSafe(String? raw) => sanitize(raw) != null;

  static bool isInternal(String? raw) {
    final s = sanitize(raw);
    return s != null && s.startsWith('/');
  }

  static bool isExternal(String? raw) {
    final s = sanitize(raw);
    return s != null && (s.startsWith('http://') || s.startsWith('https://'));
  }

  static bool _looksLikeHost(String host) {
    if (host.contains(' ')) return false;
    if (host == 'localhost') return true;
    return host.contains('.');
  }

  /// Classify a sanitized link for Story/post metadata.
  static String classifyKind(String sanitized) {
    if (sanitized.startsWith('/business')) return 'business';
    if (sanitized.startsWith('/community')) return 'community';
    if (sanitized.startsWith('/group')) return 'group';
    if (sanitized.startsWith('/event')) return 'event';
    if (sanitized.startsWith('/member') || sanitized.startsWith('/profile')) {
      return 'profile';
    }
    if (sanitized.startsWith('/post')) return 'post';
    if (sanitized.startsWith('/')) return 'route';
    return 'external';
  }
}
