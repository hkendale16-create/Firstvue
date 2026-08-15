/// Central product / pricing identifiers.
///
/// Prices and store product IDs live in `monetization_products` (server) and
/// optionally in [MonetizationProductCatalog] fallbacks — never scatter
/// hardcoded dollar amounts through UI business logic.
class MonetizationProductIds {
  MonetizationProductIds._();

  static const firstVuePlus = 'firstvue_plus';
  static const businessVerified = 'business_verified';
  static const businessPro = 'business_pro';
  static const vueBountyDefault = 'vue_bounty_default';
  static const shareAndEarnDefault = 'share_and_earn_default';
  static const postBoostLocalSmall = 'post_boost_local_small';
  static const postBoostLocalLarge = 'post_boost_local_large';
  static const postBoostMultiDay = 'post_boost_multi_day';

  static const postBoostTierIds = <String>[
    postBoostLocalSmall,
    postBoostLocalLarge,
    postBoostMultiDay,
  ];
}

class MonetizationFlagKeys {
  MonetizationFlagKeys._();

  static const businessSubscriptions = 'business_subscriptions';
  static const businessBoosts = 'business_boosts';
  static const vueBounties = 'vue_bounties';
  static const bountyFunding = 'bounty_funding';
  static const creatorPayouts = 'creator_payouts';
  static const affiliateRewards = 'affiliate_rewards';
  static const ticketing = 'ticketing';

  static const all = <String>[
    businessSubscriptions,
    businessBoosts,
    vueBounties,
    bountyFunding,
    creatorPayouts,
    affiliateRewards,
    ticketing,
  ];
}

class MonetizationProduct {
  final String id;
  final String displayName;
  final String productFamily;
  final String? billingPeriod;
  final int? priceCents;
  final String currency;
  final String? stripePriceId;
  final String? appleProductId;
  final String? googleProductId;
  final int platformFeeBps;
  final bool isActive;

  const MonetizationProduct({
    required this.id,
    required this.displayName,
    required this.productFamily,
    this.billingPeriod,
    this.priceCents,
    this.currency = 'usd',
    this.stripePriceId,
    this.appleProductId,
    this.googleProductId,
    this.platformFeeBps = 1500,
    this.isActive = false,
  });

  factory MonetizationProduct.fromMap(Map<String, dynamic> map) {
    return MonetizationProduct(
      id: map['id'] as String,
      displayName: map['display_name'] as String? ?? map['id'] as String,
      productFamily: map['product_family'] as String? ?? 'other',
      billingPeriod: map['billing_period'] as String?,
      priceCents: (map['price_cents'] as num?)?.toInt(),
      currency: map['currency'] as String? ?? 'usd',
      stripePriceId: map['stripe_price_id'] as String?,
      appleProductId: map['apple_product_id'] as String?,
      googleProductId: map['google_product_id'] as String?,
      platformFeeBps: (map['platform_fee_bps'] as num?)?.toInt() ?? 1500,
      isActive: map['is_active'] as bool? ?? false,
    );
  }

  /// Display helper — never use for accounting math.
  String get priceLabel {
    final cents = priceCents;
    if (cents == null) return 'Not priced';
    final dollars = cents / 100.0;
    final period = billingPeriod == 'month'
        ? '/mo'
        : billingPeriod == 'year'
            ? '/yr'
            : '';
    return '\$${dollars.toStringAsFixed(2)}$period';
  }
}

/// Compile-time catalog fallbacks when the DB row is unavailable.
/// Values are conceptual defaults — server rows are source of truth.
class MonetizationProductCatalog {
  MonetizationProductCatalog._();

  static const fallbacks = <MonetizationProduct>[
    MonetizationProduct(
      id: MonetizationProductIds.firstVuePlus,
      displayName: 'FirstVue+',
      productFamily: 'consumer_plus',
      billingPeriod: 'month',
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.businessVerified,
      displayName: 'FirstVue Verified',
      productFamily: 'business_subscription',
      billingPeriod: 'month',
      priceCents: 999,
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.businessPro,
      displayName: 'FirstVue Pro',
      productFamily: 'business_subscription',
      billingPeriod: 'month',
      priceCents: 2999,
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.vueBountyDefault,
      displayName: 'VUE Bounty Campaign',
      productFamily: 'bounty_campaign',
      platformFeeBps: 1500,
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.shareAndEarnDefault,
      displayName: 'Share & Earn',
      productFamily: 'affiliate_program',
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.postBoostLocalSmall,
      displayName: 'Small Local Boost',
      productFamily: 'post_boost',
      billingPeriod: 'one_time',
      priceCents: 500,
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.postBoostLocalLarge,
      displayName: 'Larger Local Reach',
      productFamily: 'post_boost',
      billingPeriod: 'one_time',
      priceCents: 1500,
      isActive: false,
    ),
    MonetizationProduct(
      id: MonetizationProductIds.postBoostMultiDay,
      displayName: 'Multi-Day Promotion',
      productFamily: 'post_boost',
      billingPeriod: 'one_time',
      priceCents: 3000,
      isActive: false,
    ),
  ];

  static List<MonetizationProduct> postBoostTiers() {
    return [
      for (final id in MonetizationProductIds.postBoostTierIds)
        fallbackById(id),
    ];
  }

  static MonetizationProduct fallbackById(String id) {
    return fallbacks.firstWhere(
      (p) => p.id == id,
      orElse: () => MonetizationProduct(
        id: id,
        displayName: id,
        productFamily: 'other',
      ),
    );
  }
}

/// Integer minor-unit money helpers. Never use floating-point for accounting.
class MoneyCents {
  MoneyCents._();

  static String formatUsd(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    return '$sign\$$whole.$frac';
  }

  static int platformFeeCents({
    required int spendCents,
    required int feeBps,
  }) {
    // Round half away from zero using integer math.
    final raw = spendCents * feeBps;
    return (raw + 5000) ~/ 10000;
  }

  static int creatorAllocationCents({
    required int spendCents,
    required int feeBps,
  }) {
    return spendCents - platformFeeCents(spendCents: spendCents, feeBps: feeBps);
  }
}
