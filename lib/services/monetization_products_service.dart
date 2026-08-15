import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/monetization_config.dart';

class MonetizationProductsService {
  MonetizationProductsService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<MonetizationProduct>> fetchProducts() async {
    try {
      final rows = await _client.from('monetization_products').select();
      if (rows.isEmpty) return MonetizationProductCatalog.fallbacks;
      return rows
          .map((row) => MonetizationProduct.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return MonetizationProductCatalog.fallbacks;
    }
  }

  static Future<MonetizationProduct> fetchById(String id) async {
    try {
      final row = await _client
          .from('monetization_products')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return MonetizationProductCatalog.fallbackById(id);
      return MonetizationProduct.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      return MonetizationProductCatalog.fallbackById(id);
    }
  }
}
