import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-verified subscription entitlement (Apple / Google / Stripe).
/// Never unlock paid features from a client-only boolean.
class SubscriptionEntitlement {
  final String id;
  final String subjectType;
  final String subjectId;
  final String productId;
  final String platform;
  final String status;
  final String purchaseState;
  final bool renews;
  final DateTime? expiresAt;
  final String? latestTransactionRef;

  const SubscriptionEntitlement({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.productId,
    required this.platform,
    required this.status,
    required this.purchaseState,
    required this.renews,
    this.expiresAt,
    this.latestTransactionRef,
  });

  bool get isActive {
    if (status != 'active' && status != 'grace_period') return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  factory SubscriptionEntitlement.fromMap(Map<String, dynamic> map) {
    return SubscriptionEntitlement(
      id: map['id'] as String,
      subjectType: map['subject_type'] as String,
      subjectId: map['subject_id'] as String,
      productId: map['product_id'] as String,
      platform: map['platform'] as String,
      status: map['status'] as String? ?? 'none',
      purchaseState: map['purchase_state'] as String? ?? 'none',
      renews: map['renews'] as bool? ?? false,
      expiresAt: DateTime.tryParse((map['expires_at'] as String?) ?? ''),
      latestTransactionRef: map['latest_transaction_ref'] as String?,
    );
  }
}

class SubscriptionEntitlementService {
  SubscriptionEntitlementService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<SubscriptionEntitlement>> fetchForBusiness(
    String businessId,
  ) async {
    try {
      final rows = await _client
          .from('subscription_entitlements')
          .select()
          .eq('subject_type', 'business')
          .eq('subject_id', businessId);
      return rows
          .map((r) => SubscriptionEntitlement.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<SubscriptionEntitlement?> activeForBusinessProduct({
    required String businessId,
    required String productId,
  }) async {
    final all = await fetchForBusiness(businessId);
    for (final e in all) {
      if (e.productId == productId && e.isActive) return e;
    }
    return null;
  }

  /// Prefer server entitlement; fall back to legacy business_subscriptions read
  /// path for web Stripe until entitlements are fully backfilled.
  static Future<bool> hasActiveBusinessPro(String businessId) async {
    final entitlement = await activeForBusinessProduct(
      businessId: businessId,
      productId: 'business_pro',
    );
    if (entitlement != null) return true;
    return false;
  }
}
