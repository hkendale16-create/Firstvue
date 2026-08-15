import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:firstvue/config/monetization_config.dart';

void main() {
  test('payments and monetization flags default off except vue bounties', () {
    final flags = File('lib/config/feature_flags.dart').readAsStringSync();
    expect(flags, contains('FIRSTVUE_PAYMENTS'));
    expect(flags, contains('FIRSTVUE_BOUNTY_FUNDING'));
    expect(flags, contains('FIRSTVUE_CREATOR_PAYOUTS'));
    expect(flags, contains('FIRSTVUE_AFFILIATE_REWARDS'));
    expect(flags, contains('FIRSTVUE_TICKETING'));
    expect(flags, contains("defaultValue: false"));
    expect(flags, contains('FIRSTVUE_VUE_BOUNTIES'));
    // vue bounties may default true for architecture UI
    expect(flags, contains("'FIRSTVUE_VUE_BOUNTIES'"));
  });

  test('checkout remains gated on effective business subscriptions', () {
    final stripe =
        File('lib/services/stripe_billing_service.dart').readAsStringSync();
    expect(stripe, contains('FeatureFlags.effectiveBusinessSubscriptions'));
  });

  test('money helpers use integer cents', () {
    expect(MoneyCents.formatUsd(1250), '\$12.50');
    expect(MoneyCents.formatUsd(0), '\$0.00');
    expect(MoneyCents.formatUsd(-50), '-\$0.50');
    expect(
      MoneyCents.platformFeeCents(spendCents: 50000, feeBps: 2000),
      10000,
    );
    expect(
      MoneyCents.creatorAllocationCents(spendCents: 50000, feeBps: 2000),
      40000,
    );
  });

  test('product catalog keeps Pro price configurable centrally', () {
    final pro = MonetizationProductCatalog.fallbackById(
      MonetizationProductIds.businessPro,
    );
    expect(pro.priceCents, 2999);
    expect(pro.isActive, isFalse);
    final plus = MonetizationProductCatalog.fallbackById(
      MonetizationProductIds.firstVuePlus,
    );
    expect(plus.priceCents, isNull);
    expect(plus.isActive, isFalse);
  });

  test('monetization migration and UI foundation files exist', () {
    expect(
      File('supabase/migrations/20261010_monetization_vue_bounties_foundation.sql')
          .existsSync(),
      isTrue,
    );
    expect(File('lib/services/bounty_service.dart').existsSync(), isTrue);
    expect(
      File('lib/services/creator_earnings_service.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/services/subscription_entitlement_service.dart').existsSync(),
      isTrue,
    );
    expect(File('lib/screens/bounty_discovery_screen.dart').existsSync(), isTrue);
    expect(File('lib/screens/creator_earnings_screen.dart').existsSync(), isTrue);
    expect(
      File('lib/screens/business_campaign_dashboard_screen.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/screens/admin_financial_controls_screen.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/widgets/sponsored_disclosure_badge.dart').existsSync(),
      isTrue,
    );
  });

  test('migration blocks client financial writes and locks requirements', () {
    final sql = File(
      'supabase/migrations/20261010_monetization_vue_bounties_foundation.sql',
    ).readAsStringSync();
    expect(sql, contains('fv_block_client_financial_insert'));
    expect(sql, contains('fv_protect_bounty_money_fields'));
    expect(sql, contains('fv_prevent_locked_requirement_edit'));
    expect(sql, contains('financial_ledger_entries'));
    expect(sql, contains('subscription_entitlements'));
    expect(sql, contains('bounty_campaigns'));
    expect(sql, contains('affiliate_conversions'));
    expect(sql, contains('campaign_disputes'));
    expect(sql, contains('account_risk_states'));
    expect(sql, contains('financial_audit_log'));
    expect(sql, contains("flag_key, enabled"));
    expect(sql, contains("'bounty_funding', false"));
    expect(sql, contains("'creator_payouts', false"));
  });

  test('payout and funding CTAs stay feature gated in services', () {
    final bounty = File('lib/services/bounty_service.dart').readAsStringSync();
    expect(bounty, contains('canShowFundingActions'));
    expect(bounty, contains('FeatureFlags.bountyFundingEnabled'));
    final earnings =
        File('lib/services/creator_earnings_service.dart').readAsStringSync();
    expect(earnings, contains('canShowPayoutActions'));
    expect(earnings, contains('FeatureFlags.creatorPayoutsEnabled'));
  });
}
