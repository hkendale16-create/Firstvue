import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessMenuItem {
  final String id;
  final String name;
  final String? description;
  final String? priceLabel;
  final String category;
  final String? imageStoragePath;
  final bool isAvailable;
  final int sortOrder;

  const BusinessMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.priceLabel,
    required this.category,
    this.imageStoragePath,
    this.isAvailable = true,
    this.sortOrder = 0,
  });

  BusinessMenuItem copyWith({
    String? id,
    String? name,
    String? description,
    String? priceLabel,
    String? category,
    String? imageStoragePath,
    bool? isAvailable,
    int? sortOrder,
    bool clearImage = false,
  }) {
    return BusinessMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priceLabel: priceLabel ?? this.priceLabel,
      category: category ?? this.category,
      imageStoragePath:
          clearImage ? null : (imageStoragePath ?? this.imageStoragePath),
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class BusinessMenuCategory {
  final String name;
  final List<BusinessMenuItem> items;

  const BusinessMenuCategory({
    required this.name,
    required this.items,
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

  /// Groups items by category, preserving first-seen category order and
  /// within-category [BusinessMenuItem.sortOrder] order.
  static List<BusinessMenuCategory> groupByCategory(
    List<BusinessMenuItem> items, {
    bool includeUnavailable = true,
  }) {
    final filtered = includeUnavailable
        ? items
        : items.where((item) => item.isAvailable).toList();
    final order = <String>[];
    final buckets = <String, List<BusinessMenuItem>>{};
    for (final item in filtered) {
      final key = item.category.trim().isEmpty ? 'Menu' : item.category.trim();
      if (!buckets.containsKey(key)) {
        order.add(key);
        buckets[key] = [];
      }
      buckets[key]!.add(item);
    }
    return [
      for (final name in order)
        BusinessMenuCategory(
          name: name,
          items: List<BusinessMenuItem>.from(buckets[name]!)
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
        ),
    ];
  }

  static BusinessMenuItem _fromRow(Map<String, dynamic> row) {
    return BusinessMenuItem(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      priceLabel: row['price_label'] as String?,
      category: (row['category'] as String?) ?? 'Menu',
      imageStoragePath: row['image_storage_path'] as String?,
      isAvailable: (row['is_available'] as bool?) ?? true,
      sortOrder: (row['sort_order'] as int?) ?? 0,
    );
  }

  static Future<List<BusinessMenuItem>> fetchMenuItems(
    String businessId, {
    bool availableOnly = false,
  }) async {
    try {
      final filter = _client
          .from('business_menu_items')
          .select(
            'id, name, description, price_label, category, '
            'image_storage_path, is_available, sort_order',
          )
          .eq('business_id', businessId);
      final rows = availableOnly
          ? await filter
              .eq('is_available', true)
              .order('category', ascending: true)
              .order('sort_order', ascending: true)
          : await filter
              .order('category', ascending: true)
              .order('sort_order', ascending: true);
      return rows.map((row) => _fromRow(Map<String, dynamic>.from(row))).toList();
    } catch (_) {
      try {
        final rows = await _client
            .from('business_menu_items')
            .select('id, name, description, price_label, category, sort_order')
            .eq('business_id', businessId)
            .order('category', ascending: true)
            .order('sort_order', ascending: true);
        return rows
            .map((row) => _fromRow(Map<String, dynamic>.from(row)))
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  /// Distinct category names plus grouped items for the editor.
  static Future<({List<String> categories, List<BusinessMenuItem> items})>
      listCategories(String businessId) async {
    final items = await fetchMenuItems(businessId);
    final categories = <String>[];
    final seen = <String>{};
    for (final item in items) {
      final key = item.category.trim().isEmpty ? 'Menu' : item.category.trim();
      if (seen.add(key)) categories.add(key);
    }
    return (categories: categories, items: items);
  }

  static Future<BusinessMenuItem> upsertItem({
    required String businessId,
    String? id,
    required String name,
    String? description,
    String? priceLabel,
    String category = 'Menu',
    String? imageStoragePath,
    bool clearImage = false,
    bool isAvailable = true,
    int? sortOrder,
  }) async {
    final trimmedCategory =
        category.trim().isEmpty ? 'Menu' : category.trim();
    final payload = <String, dynamic>{
      'business_id': businessId,
      'name': name.trim(),
      'description': description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      'price_label':
          priceLabel?.trim().isEmpty == true ? null : priceLabel?.trim(),
      'category': trimmedCategory,
      'is_available': isAvailable,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (clearImage) {
      payload['image_storage_path'] = null;
    } else if (imageStoragePath != null) {
      payload['image_storage_path'] = imageStoragePath;
    }
    if (sortOrder != null) {
      payload['sort_order'] = sortOrder;
    }

    if (id == null || id.isEmpty) {
      if (sortOrder == null) {
        final existing = await fetchMenuItems(businessId);
        final inCategory =
            existing.where((item) => item.category == trimmedCategory);
        final maxOrder = inCategory.isEmpty
            ? -1
            : inCategory
                .map((item) => item.sortOrder)
                .reduce((a, b) => a > b ? a : b);
        payload['sort_order'] = maxOrder + 1;
      }
      final row = await _client
          .from('business_menu_items')
          .insert(payload)
          .select(
            'id, name, description, price_label, category, '
            'image_storage_path, is_available, sort_order',
          )
          .single();
      return _fromRow(Map<String, dynamic>.from(row));
    }

    try {
      final row = await _client
          .from('business_menu_items')
          .update(payload)
          .eq('id', id)
          .eq('business_id', businessId)
          .select(
            'id, name, description, price_label, category, '
            'image_storage_path, is_available, sort_order',
          )
          .single();
      return _fromRow(Map<String, dynamic>.from(row));
    } catch (_) {
      // Columns may be missing before migration — retry without new fields.
      final legacy = <String, dynamic>{
        'name': payload['name'],
        'description': payload['description'],
        'price_label': payload['price_label'],
        'category': payload['category'],
        'sort_order': ?sortOrder,
      };
      final row = await _client
          .from('business_menu_items')
          .update(legacy)
          .eq('id', id)
          .eq('business_id', businessId)
          .select('id, name, description, price_label, category, sort_order')
          .single();
      return _fromRow(Map<String, dynamic>.from(row));
    }
  }

  static Future<void> deleteItem({
    required String businessId,
    required String itemId,
  }) async {
    await _client
        .from('business_menu_items')
        .delete()
        .eq('id', itemId)
        .eq('business_id', businessId);
  }

  /// Reorders [orderedItemIds] within a category (0-based sort_order).
  static Future<void> reorderItems({
    required String businessId,
    required List<String> orderedItemIds,
  }) async {
    for (var i = 0; i < orderedItemIds.length; i++) {
      await _client
          .from('business_menu_items')
          .update({'sort_order': i})
          .eq('id', orderedItemIds[i])
          .eq('business_id', businessId);
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
    required List<
            ({String name, String description, String price, String category})>
        items,
  }) async {
    await _client
        .from('business_menu_items')
        .delete()
        .eq('business_id', businessId);
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
                  'is_available': true,
                },
              )
              .toList(),
        );
  }

  static Future<void> replaceSpecials({
    required String businessId,
    required List<({String title, String description, String price})> specials,
  }) async {
    await _client
        .from('business_specials')
        .delete()
        .eq('business_id', businessId);
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
