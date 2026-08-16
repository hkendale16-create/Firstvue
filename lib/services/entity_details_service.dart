import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/entity_details_form.dart';
import 'cache/cache_ttls.dart';
import 'cache/ttl_memory_cache.dart';

/// Loads/saves `entity_details` jsonb (+ promoted columns when present).
class EntityDetailsService {
  EntityDetailsService._();

  static final _client = Supabase.instance.client;

  static final _cache = TtlMemoryCache<Map<String, dynamic>>(
    ttl: CacheTtls.entityDetails,
    maxEntries: 120,
    name: 'entity_details',
  );

  static void clearCache() => _cache.clear();

  static Future<Map<String, dynamic>> fetchBusinessDetails(
    String businessId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _cache.getFresh(businessId);
      if (cached != null) return Map<String, dynamic>.from(cached);
      final stale = _cache.peek(businessId);
      if (stale != null) {
        // ignore: unawaited_futures
        _loadBusinessDetails(businessId).then((_) {}, onError: (_) {});
        return Map<String, dynamic>.from(stale);
      }
    }
    return _loadBusinessDetails(businessId);
  }

  static Future<Map<String, dynamic>> _loadBusinessDetails(
    String businessId,
  ) async {
    try {
      final row = await _client
          .from('businesses')
          .select('entity_details, subcategory, phone, website, price_range, service_area')
          .eq('id', businessId)
          .maybeSingle();
      if (row == null) return {};
      final details = parseEntityDetails(row['entity_details']);
      void put(String key, dynamic value) {
        if (value == null) return;
        final text = value.toString().trim();
        if (text.isEmpty) return;
        details.putIfAbsent(key, () => value);
      }
      put('subcategory', row['subcategory']);
      put('phone', row['phone']);
      put('website', row['website']);
      put('price_range', row['price_range']);
      put('service_area', row['service_area']);
      _cache.put(businessId, details);
      return details;
    } catch (_) {
      try {
        final row = await _client
            .from('businesses')
            .select('entity_details')
            .eq('id', businessId)
            .maybeSingle();
        final details = parseEntityDetails(row?['entity_details']);
        _cache.put(businessId, details);
        return details;
      } catch (_) {
        return {};
      }
    }
  }

  static Future<void> saveBusinessDetails(
    String businessId,
    Map<String, dynamic> details,
  ) async {
    final cleaned = _clean(details);
    _cache.invalidate(businessId);
    final patch = <String, dynamic>{
      'entity_details': cleaned,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final key in ['price_range', 'service_area', 'phone', 'website', 'subcategory']) {
      if (cleaned.containsKey(key)) patch[key] = cleaned[key];
    }
    try {
      await _client.from('businesses').update(patch).eq('id', businessId);
    } catch (_) {
      await _client.from('businesses').update({
        'entity_details': cleaned,
        'updated_at': patch['updated_at'],
      }).eq('id', businessId);
    }
  }

  static Future<Map<String, dynamic>> fetchProfessionalDetails(
    String professionalProfileId,
  ) async {
    try {
      final row = await _client
          .from('professional_profiles')
          .select(
            'entity_details, title, company, specialty, experience_years, service_area',
          )
          .eq('id', professionalProfileId)
          .maybeSingle();
      if (row == null) return {};
      final details = parseEntityDetails(row['entity_details']);
      void put(String key, dynamic value) {
        if (value == null) return;
        details.putIfAbsent(key, () => value);
      }
      put('title', row['title']);
      put('company', row['company']);
      put('specialty', row['specialty']);
      put('experience_years', row['experience_years']);
      put('service_area', row['service_area']);
      return details;
    } catch (_) {
      try {
        final row = await _client
            .from('professional_profiles')
            .select('entity_details')
            .eq('id', professionalProfileId)
            .maybeSingle();
        return parseEntityDetails(row?['entity_details']);
      } catch (_) {
        return {};
      }
    }
  }

  static Future<void> saveProfessionalDetails(
    String professionalProfileId,
    Map<String, dynamic> details,
  ) async {
    final cleaned = _clean(details);
    final patch = <String, dynamic>{
      'entity_details': cleaned,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final key in [
      'title',
      'company',
      'specialty',
      'experience_years',
      'service_area',
    ]) {
      if (cleaned.containsKey(key)) patch[key] = cleaned[key];
    }
    try {
      await _client
          .from('professional_profiles')
          .update(patch)
          .eq('id', professionalProfileId);
    } catch (_) {
      await _client.from('professional_profiles').update({
        'entity_details': cleaned,
        'updated_at': patch['updated_at'],
      }).eq('id', professionalProfileId);
    }
  }

  static Future<Map<String, dynamic>> fetchRentalDetails(String rentalId) async {
    try {
      final row = await _client
          .from('rentals')
          .select(
            'entity_details, property_type, bedrooms, bathrooms, '
            'square_footage, deposit_cents, lease_length, pet_policy',
          )
          .eq('id', rentalId)
          .maybeSingle();
      if (row == null) return {};
      final details = parseEntityDetails(row['entity_details']);
      row.forEach((key, value) {
        if (key == 'entity_details' || value == null) return;
        details.putIfAbsent(key, () => value);
      });
      return details;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveRentalDetails(
    String rentalId,
    Map<String, dynamic> details,
  ) async {
    final cleaned = _clean(details);
    final patch = <String, dynamic>{
      'entity_details': cleaned,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final key in [
      'property_type',
      'bedrooms',
      'bathrooms',
      'square_footage',
      'deposit_cents',
      'lease_length',
      'pet_policy',
    ]) {
      if (cleaned.containsKey(key)) patch[key] = cleaned[key];
    }
    try {
      await _client.from('rentals').update(patch).eq('id', rentalId);
    } catch (_) {
      await _client.from('rentals').update({
        'entity_details': cleaned,
        'updated_at': patch['updated_at'],
      }).eq('id', rentalId);
    }
  }

  static Map<String, dynamic> _clean(Map<String, dynamic> details) {
    final out = <String, dynamic>{};
    details.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      out[key] = value;
    });
    return out;
  }
}
