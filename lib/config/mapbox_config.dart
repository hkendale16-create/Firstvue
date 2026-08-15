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
}
