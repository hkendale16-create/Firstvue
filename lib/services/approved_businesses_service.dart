import 'package:supabase_flutter/supabase_flutter.dart';

import 'cache/cache_ttls.dart';
import 'cache/ttl_memory_cache.dart';

class ApprovedBusiness {
  final String id;
  final String name;
  final String businessType;

  const ApprovedBusiness({
    required this.id,
    required this.name,
    required this.businessType,
  });

  factory ApprovedBusiness.fromMap(Map<String, dynamic> map) {
    return ApprovedBusiness(
      id: map['id'] as String,
      name: map['name'] as String,
      businessType: (map['business_type'] as String?) ?? 'Service business',
    );
  }
}

class PublicBusinessDetails {
  final String id;
  final String name;
  final String businessType;
  final String? description;
  final String? address;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final List<String> services;

  const PublicBusinessDetails({
    required this.id,
    required this.name,
    required this.businessType,
    required this.description,
    required this.address,
    required this.services,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
  });

  String? get cityStateLabel {
    final parts = [
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((state ?? '').trim().isNotEmpty) state!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  bool get hasMapCoordinates => latitude != null && longitude != null;
}

class ApprovedBusinessesService {
  ApprovedBusinessesService._();

  static final _cache = TtlMemoryCache<PublicBusinessDetails>(
    ttl: CacheTtls.business,
    maxEntries: 120,
    name: 'businesses',
  );

  static void clearCache() => _cache.clear();

  static Stream<List<ApprovedBusiness>> watchApprovedBusinesses() {
    return Supabase.instance.client
        .from('businesses')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ApprovedBusiness.fromMap).toList());
  }

  static Future<PublicBusinessDetails> fetchPublicBusiness(
    String businessId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _cache.getFresh(businessId);
      if (cached != null) return cached;
      final stale = _cache.peek(businessId);
      if (stale != null) {
        // ignore: unawaited_futures
        _fetchAndCache(businessId).then((_) {}, onError: (_) {});
        return stale;
      }
    }
    return _fetchAndCache(businessId);
  }

  static Future<PublicBusinessDetails> _fetchAndCache(String businessId) async {
    final client = Supabase.instance.client;
    final business = await client
        .from('businesses')
        .select('id, name, business_type, description, services')
        .eq('id', businessId)
        .single();
    final location = await client
        .from('business_locations')
        .select(
          'address_line_1, city, state, postal_code, latitude, longitude',
        )
        .eq('business_id', businessId)
        .maybeSingle();

    final locationParts = [
      location?['address_line_1'] as String?,
      location?['city'] as String?,
      location?['state'] as String?,
      location?['postal_code'] as String?,
    ].whereType<String>().where((part) => part.isNotEmpty);

    final details = PublicBusinessDetails(
      id: business['id'] as String,
      name: business['name'] as String,
      businessType:
          (business['business_type'] as String?) ?? 'Service business',
      description: business['description'] as String?,
      address: locationParts.isEmpty ? null : locationParts.join(', '),
      city: location?['city'] as String?,
      state: location?['state'] as String?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      services: List<String>.from((business['services'] as List?) ?? const []),
    );
    _cache.put(businessId, details);
    return details;
  }
}
