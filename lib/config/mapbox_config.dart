import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Mapbox credentials for LIVE 3D map.
///
/// Pass at build/run time:
/// `--dart-define=MAPBOX_ACCESS_TOKEN=pk....`
/// Optional custom neon style:
/// `--dart-define=MAPBOX_STYLE_URI=mapbox://styles/your-user/your-style`
class MapboxConfig {
  MapboxConfig._();

  static const accessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  /// Falls back to Mapbox Dark v11 (supports 3D buildings when pitched).
  static const styleUri = String.fromEnvironment(
    'MAPBOX_STYLE_URI',
    defaultValue: 'mapbox://styles/mapbox/dark-v11',
  );

  static bool get hasAccessToken => accessToken.trim().isNotEmpty;

  /// True only when the native Mapbox surface can actually run.
  /// Web/desktop always use the OSM fallback even if a token is present.
  static bool get canUseNativeMap {
    if (!hasAccessToken || kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Short status line when Mapbox 3D is not active.
  static String get fallbackBanner {
    if (kIsWeb) {
      return '3D neon Mapbox runs in the iOS/Android app. Showing the dark web map.';
    }
    if (!hasAccessToken) {
      return 'Add MAPBOX_ACCESS_TOKEN when building the iOS/Android app for pitched 3D buildings.';
    }
    return 'Mapbox 3D needs an iOS or Android device. Showing the dark fallback map.';
  }
}
