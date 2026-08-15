import 'monetization_config.dart';

/// Feature flags for incomplete platform capabilities.
///
/// Monetization money flows default OFF. [vueBountiesEnabled] may be ON for
/// architecture/UI testing without funding or payouts.
class FeatureFlags {
  FeatureFlags._();

  /// Go Live is shown next to Video only when a working live architecture
  /// is compiled in. Default off — do not ship a false action.
  static const liveStreamingEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_STREAMING',
    defaultValue: false,
  );

  /// Stripe checkout and paid upgrades. Default off during trial.
  /// Prefer [businessSubscriptionsEnabled] for new call sites.
  static const paymentsEnabled = bool.fromEnvironment(
    'FIRSTVUE_PAYMENTS',
    defaultValue: false,
  );

  /// Business subscription checkout (Stripe web / future IAP).
  static const businessSubscriptionsEnabled = bool.fromEnvironment(
    'FIRSTVUE_BUSINESS_SUBSCRIPTIONS',
    defaultValue: false,
  );

  /// Paid business / event boost placements.
  static const businessBoostsEnabled = bool.fromEnvironment(
    'FIRSTVUE_BUSINESS_BOOSTS',
    defaultValue: false,
  );

  /// VUE Bounty architecture + discovery UI (no real funding).
  static const vueBountiesEnabled = bool.fromEnvironment(
    'FIRSTVUE_VUE_BOUNTIES',
    defaultValue: true,
  );

  /// Real campaign funding authorization. Keep false until provider approved.
  static const bountyFundingEnabled = bool.fromEnvironment(
    'FIRSTVUE_BOUNTY_FUNDING',
    defaultValue: false,
  );

  /// Creator cash payouts / withdrawals.
  static const creatorPayoutsEnabled = bool.fromEnvironment(
    'FIRSTVUE_CREATOR_PAYOUTS',
    defaultValue: false,
  );

  /// Share & Earn cash rewards.
  static const affiliateRewardsEnabled = bool.fromEnvironment(
    'FIRSTVUE_AFFILIATE_REWARDS',
    defaultValue: false,
  );

  /// Paid ticketing.
  static const ticketingEnabled = bool.fromEnvironment(
    'FIRSTVUE_TICKETING',
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
    defaultValue: true,
  );

  /// I'm Here / Here Now presence (Phase 3).
  static const liveEventPresenceEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_EVENT_PRESENCE',
    defaultValue: true,
  );

  /// Event conversation entry from LIVE detail (Phase 3).
  static const liveEventChatEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_EVENT_CHAT',
    defaultValue: true,
  );

  /// Food Truck / business LIVE open sessions (Phase 8).
  /// Disable with `--dart-define=FIRSTVUE_LIVE_FOOD_TRUCKS=false`.
  static const liveFoodTrucksEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_FOOD_TRUCKS',
    defaultValue: true,
  );

  /// Heating Up / activity scores (Phase 5).
  static const liveHeatActivityEnabled = bool.fromEnvironment(
    'FIRSTVUE_LIVE_HEAT_ACTIVITY',
    defaultValue: true,
  );

  /// Effective business subscription gate: compile-time OR legacy payments flag.
  static bool get effectiveBusinessSubscriptions =>
      paymentsEnabled || businessSubscriptionsEnabled;

  /// True when any real-money path is compile-enabled (still requires server flag).
  static bool get anyRealMoneyCompileEnabled =>
      effectiveBusinessSubscriptions ||
      businessBoostsEnabled ||
      bountyFundingEnabled ||
      creatorPayoutsEnabled ||
      affiliateRewardsEnabled ||
      ticketingEnabled;

  /// Resolve a monetization flag using compile-time default + optional server override.
  static bool resolve(String flagKey, {bool? serverEnabled}) {
    final compile = switch (flagKey) {
      MonetizationFlagKeys.businessSubscriptions =>
        effectiveBusinessSubscriptions,
      MonetizationFlagKeys.businessBoosts => businessBoostsEnabled,
      MonetizationFlagKeys.vueBounties => vueBountiesEnabled,
      MonetizationFlagKeys.bountyFunding => bountyFundingEnabled,
      MonetizationFlagKeys.creatorPayouts => creatorPayoutsEnabled,
      MonetizationFlagKeys.affiliateRewards => affiliateRewardsEnabled,
      MonetizationFlagKeys.ticketing => ticketingEnabled,
      _ => false,
    };
    // Both must be true when a server value is known; compile alone for offline.
    if (serverEnabled == null) return compile;
    return compile && serverEnabled;
  }
}
