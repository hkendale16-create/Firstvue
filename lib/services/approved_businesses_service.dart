import 'package:supabase_flutter/supabase_flutter.dart';

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
  final List<String> services;

  const PublicBusinessDetails({
    required this.id,
    required this.name,
    required this.businessType,
    required this.description,
    required this.address,
    required this.services,
  });
}

class ApprovedBusinessesService {
  ApprovedBusinessesService._();

  static Stream<List<ApprovedBusiness>> watchApprovedBusinesses() {
    return Supabase.instance.client
        .from('businesses')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ApprovedBusiness.fromMap).toList());
  }

  static Future<PublicBusinessDetails> fetchPublicBusiness(
    String businessId,
  ) async {
    final client = Supabase.instance.client;
    final business = await client
        .from('businesses')
        .select('id, name, business_type, description, services')
        .eq('id', businessId)
        .single();
    final location = await client
        .from('business_locations')
        .select('address_line_1, city, state, postal_code')
        .eq('business_id', businessId)
        .maybeSingle();

    final locationParts = [
      location?['address_line_1'] as String?,
      location?['city'] as String?,
      location?['state'] as String?,
      location?['postal_code'] as String?,
    ].whereType<String>().where((part) => part.isNotEmpty);

    return PublicBusinessDetails(
      id: business['id'] as String,
      name: business['name'] as String,
      businessType:
          (business['business_type'] as String?) ?? 'Service business',
      description: business['description'] as String?,
      address: locationParts.isEmpty ? null : locationParts.join(', '),
      services: List<String>.from((business['services'] as List?) ?? const []),
    );
  }
}
