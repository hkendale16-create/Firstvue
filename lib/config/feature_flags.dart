/// Feature flags for incomplete platform capabilities.
class FeatureFlags {
  FeatureFlags._();

  /// Go Live is shown next to Video only when a working live architecture
  /// is compiled in. Default off — do not ship a false action.
  static const liveStreamingEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_STREAMING',
    defaultValue: false,
  );

  /// Stripe checkout and paid upgrades. Default off during trial.
  static const paymentsEnabled = bool.fromEnvironment(
    'FIRSTVUE_PAYMENTS',
    defaultValue: false,
  );

  /// Top-level VUE | LIVE mode switch and LIVE shell.
  /// Disable with `--dart-define=FIRSTVUE_LIVE_MODE=false`.
  static const liveModeEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_MODE',
    defaultValue: true,
  );

  /// LIVE map (Phase 4). Independent of [liveModeEnabled].
  static const liveMapEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_MAP',
    defaultValue: false,
  );

  /// I'm Here / Here Now presence (Phase 3).
  static const liveEventPresenceEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_EVENT_PRESENCE',
    defaultValue: false,
  );

  /// Event conversation entry from LIVE detail (Phase 3).
  static const liveEventChatEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_EVENT_CHAT',
    defaultValue: false,
  );

  /// Food Truck LIVE cards / map pins (later phases).
  static const liveFoodTrucksEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_FOOD_TRUCKS',
    defaultValue: false,
  );

  /// Heating Up / activity scores (Phase 5).
  static const liveHeatActivityEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_HEAT_ACTIVITY',
    defaultValue: false,
  );
}
