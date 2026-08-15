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
}
