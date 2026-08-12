import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessMenuItem {
  final String id;
  final String name;
  final String? description;
  final String? priceLabel;
  final String category;

  const BusinessMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceLabel,
    required this.category,
  });
}

class BusinessSpecial {
  final String id;
  final String title;
  final String? description;
  final String? priceLabel;
  final DateTime? validUntil;

  const BusinessSpecial({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.validUntil,
  });
}

class BusinessMenuService {
  BusinessMenuService._();

  static final _client = Supabase.instance.client;

  static bool isDiningBusinessType(String businessType) {
    final normalized = businessType.toLowerCase();
    return normalized.contains('restaurant') ||
        normalized.contains('bar') ||
        normalized.contains('dining') ||
        normalized.contains('cafe') ||
        normalized.contains('café') ||
        normalized.contains('bistro') ||
        normalized.contains('grill') ||
        normalized.contains('food');
  }

  static Future<List<BusinessMenuItem>> fetchMenuItems(String businessId) async {
    try {
      final rows = await _client
          .from('business_menu_items')
          .select('id, name, description, price_label, category')
          .eq('business_id', businessId)
          .order('sort_order', ascending: true);
      return rows
          .map(
            (row) => BusinessMenuItem(
              id: row['id'] as String,
              name: row['name'] as String,
              description: row['description'] as String?,
              priceLabel: row['price_label'] as String?,
              category: (row['category'] as String?) ?? 'Menu',
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<BusinessSpecial>> fetchSpecials(String businessId) async {
    try {
      final rows = await _client
          .from('business_specials')
          .select('id, title, description, price_label, valid_until')
          .eq('business_id', businessId)
          .order('sort_order', ascending: true);
      return rows
          .map(
            (row) => BusinessSpecial(
              id: row['id'] as String,
              title: row['title'] as String,
              description: row['description'] as String?,
              priceLabel: row['price_label'] as String?,
              validUntil: row['valid_until'] == null
                  ? null
                  : DateTime.parse(row['valid_until'] as String),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> replaceMenuItems({
    required String businessId,
    required List<({String name, String description, String price, String category})> items,
  }) async {
    await _client.from('business_menu_items').delete().eq('business_id', businessId);
    if (items.isEmpty) return;
    await _client.from('business_menu_items').insert(
      items
          .asMap()
          .entries
          .map(
            (entry) => {
              'business_id': businessId,
              'name': entry.value.name,
              'description': entry.value.description,
              'price_label': entry.value.price,
              'category': entry.value.category,
              'sort_order': entry.key,
            },
          )
          .toList(),
    );
  }

  static Future<void> replaceSpecials({
    required String businessId,
    required List<({String title, String description, String price})> specials,
  }) async {
    await _client.from('business_specials').delete().eq('business_id', businessId);
    if (specials.isEmpty) return;
    await _client.from('business_specials').insert(
      specials
          .asMap()
          .entries
          .map(
            (entry) => {
              'business_id': businessId,
              'title': entry.value.title,
              'description': entry.value.description,
              'price_label': entry.value.price,
              'sort_order': entry.key,
            },
          )
          .toList(),
    );
  }
}
