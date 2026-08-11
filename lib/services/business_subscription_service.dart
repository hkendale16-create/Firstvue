import 'package:supabase_flutter/supabase_flutter.dart';

enum BusinessPlan { basic, verified, pro }

class BusinessSubscription {
  final String businessId;
  final BusinessPlan plan;
  final String status;
  final int priceCents;
  final DateTime? currentPeriodEndsAt;

  const BusinessSubscription({
    required this.businessId,
    required this.plan,
    required this.status,
    required this.priceCents,
    required this.currentPeriodEndsAt,
  });

  bool get isActive => status == 'active' || status == 'trialing';

  factory BusinessSubscription.fromMap(Map<String, dynamic> map) {
    return BusinessSubscription(
      businessId: map['business_id'] as String,
      plan: BusinessPlan.values.firstWhere(
        (plan) => plan.name == (map['plan'] as String? ?? 'basic'),
        orElse: () => BusinessPlan.basic,
      ),
      status: map['status'] as String? ?? 'canceled',
      priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
      currentPeriodEndsAt: DateTime.tryParse(
        (map['current_period_ends_at'] as String?) ?? '',
      ),
    );
  }
}

class BusinessSubscriptionService {
  BusinessSubscriptionService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<BusinessSubscription?> fetchForBusiness(
    String businessId,
  ) async {
    final row = await _client
        .from('business_subscriptions')
        .select()
        .eq('business_id', businessId)
        .maybeSingle();

    if (row == null) return null;
    return BusinessSubscription.fromMap(row);
  }

  static Future<Map<String, BusinessSubscription>> fetchForBusinesses(
    Iterable<String> businessIds,
  ) async {
    final ids = businessIds.toList();
    if (ids.isEmpty) return {};

    final rows = await _client
        .from('business_subscriptions')
        .select()
        .inFilter('business_id', ids);

    return {
      for (final row in rows)
        row['business_id'] as String: BusinessSubscription.fromMap(row),
    };
  }
}
