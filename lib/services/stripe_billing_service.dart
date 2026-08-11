import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_subscription_service.dart';

class StripeBillingService {
  StripeBillingService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<String> startSubscriptionCheckout({
    required String businessId,
    required BusinessPlan plan,
  }) async {
    if (plan == BusinessPlan.basic) {
      throw ArgumentError('Basic plan does not require checkout.');
    }

    final response = await _client.functions.invoke(
      'create-checkout-session',
      body: {
        'business_id': businessId,
        'plan': plan.name,
      },
    );

    if (response.status != 200) {
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw StateError(data['error'].toString());
      }
      throw StateError('Unable to start Stripe checkout (${response.status}).');
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('Unexpected checkout response from server.');
    }

    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Stripe checkout URL was not returned.');
    }

    return url;
  }
}
