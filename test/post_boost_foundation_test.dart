import 'dart:io';

import 'package:firstvue/config/monetization_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('post boost tiers are cataloged and inactive', () {
    final tiers = MonetizationProductCatalog.postBoostTiers();
    expect(tiers, hasLength(3));
    expect(tiers.map((t) => t.id), containsAll([
      MonetizationProductIds.postBoostLocalSmall,
      MonetizationProductIds.postBoostLocalLarge,
      MonetizationProductIds.postBoostMultiDay,
    ]));
    expect(tiers.every((t) => t.productFamily == 'post_boost'), isTrue);
    expect(tiers.every((t) => t.isActive == false), isTrue);
    expect(tiers.map((t) => t.priceCents), containsAll([500, 1500, 3000]));
  });

  test('post boost migration and client files exist', () {
    expect(
      File('supabase/migrations/20261014_post_boost_drafts.sql').existsSync(),
      isTrue,
    );
    expect(File('lib/services/post_boost_service.dart').existsSync(), isTrue);
    expect(File('lib/screens/boost_post_sheet.dart').existsSync(), isTrue);
    final sql =
        File('supabase/migrations/20261014_post_boost_drafts.sql').readAsStringSync();
    expect(sql, contains('post_promotions'));
    expect(sql, contains('fv_create_post_boost_draft'));
    expect(sql, contains('fv_can_manage_post_boost'));
    expect(sql, contains("'active', 'completed'"));
    expect(sql, isNot(contains('fake payment')));
  });

  test('settings exposes Monetization section', () {
    final drawer =
        File('lib/widgets/firstvue_settings_drawer.dart').readAsStringSync();
    expect(drawer, contains("title: 'Monetization'"));
    expect(drawer, contains('Monetization & Plans'));
  });

  test('payments remain gated off by default', () {
    final flags = File('lib/config/feature_flags.dart').readAsStringSync();
    expect(flags, contains('FIRSTVUE_PAYMENTS'));
    expect(flags, contains('FIRSTVUE_BUSINESS_BOOSTS'));
    expect(flags, contains("defaultValue: false"));
  });
}
