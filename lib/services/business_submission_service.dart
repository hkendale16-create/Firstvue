import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_social_links_service.dart';

class PendingBusinessSubmission {
  final String businessId;
  final String name;
  final String businessType;
  final String contactName;
  final String contactEmail;

  const PendingBusinessSubmission({
    required this.businessId,
    required this.name,
    required this.businessType,
    required this.contactName,
    required this.contactEmail,
  });
}

class OwnedBusiness {
  final String id;
  final String name;
  final String businessType;
  final String status;
  final String description;
  final List<String> services;

  const OwnedBusiness({
    required this.id,
    required this.name,
    required this.businessType,
    required this.status,
    required this.description,
    required this.services,
  });
}

class BusinessSubmissionService {
  BusinessSubmissionService._();

  static final _client = Supabase.instance.client;

  /// Creates a pending business and verification submission.
  /// Returns the new business id so callers can upload avatar media.
  static Future<String> submitNewBusiness({
    required String name,
    required String businessType,
    required String contactName,
    required String contactEmail,
    List<String> services = const [],
    String? industrySlug,
    String? businessPhone,
    String? businessEmail,
    String? website,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? zip,
    String? contactPreference,
    List<({String platform, String url})> socialLinks = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before submitting a business.');
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': contactName,
      'account_type': 'business_owner',
      'updated_at': DateTime.now().toIso8601String(),
    });

    String? primaryIndustryId;
    final slug = (industrySlug ?? '').trim();
    if (slug.isNotEmpty) {
      try {
        final industry = await _client
            .from('industries')
            .select('id')
            .eq('slug', slug)
            .maybeSingle();
        primaryIndustryId = industry?['id'] as String?;
      } catch (_) {
        primaryIndustryId = null;
      }
    }

    final phone = businessPhone?.trim();
    final site = website?.trim();
    final publicEmail = businessEmail?.trim();
    final preference = contactPreference?.trim();

    final entityDetails = <String, dynamic>{};
    if (publicEmail != null && publicEmail.isNotEmpty) {
      entityDetails['public_email'] = publicEmail;
    }
    if (preference != null && preference.isNotEmpty) {
      entityDetails['contact_preference'] = preference;
    }

    final payload = <String, dynamic>{
      'name': name,
      'business_type': businessType,
      'created_by': user.id,
      'status': 'pending',
      'verification_status': 'pending',
      if (services.isNotEmpty) 'services': services,
      'primary_industry_id': ?primaryIndustryId,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (site != null && site.isNotEmpty) 'website': site,
      if (entityDetails.isNotEmpty) 'entity_details': entityDetails,
    };

    final business = await _client
        .from('businesses')
        .insert(payload)
        .select('id')
        .single();

    final businessId = business['id'] as String;
    try {
      await _client.from('business_verification_submissions').insert({
        'business_id': businessId,
        'submitter_id': user.id,
        'contact_name': contactName,
        'contact_email': contactEmail,
      });

      final hasLocation =
          (addressLine1?.trim().isNotEmpty ?? false) ||
          (city?.trim().isNotEmpty ?? false) ||
          (state?.trim().isNotEmpty ?? false) ||
          (zip?.trim().isNotEmpty ?? false);
      if (hasLocation) {
        await _client.from('business_locations').insert({
          'business_id': businessId,
          'address_line_1': addressLine1?.trim() ?? '',
          if (addressLine2 != null && addressLine2.trim().isNotEmpty)
            'address_line_2': addressLine2.trim(),
          'city': city?.trim() ?? '',
          'state': state?.trim() ?? '',
          'postal_code': zip?.trim() ?? '',
          'country_code': 'US',
        });
      }

      final cleanedSocials = socialLinks
          .where((l) => l.url.trim().isNotEmpty)
          .map((l) => (platform: l.platform, url: l.url.trim()))
          .toList();
      if (cleanedSocials.isNotEmpty) {
        await BusinessSocialLinksService.replaceLinks(
          businessId: businessId,
          links: cleanedSocials,
        );
      }
    } catch (_) {
      await _client.from('businesses').delete().eq('id', businessId);
      rethrow;
    }
    return businessId;
  }

  static Future<List<PendingBusinessSubmission>>
  fetchPendingSubmissions() async {
    final businesses = await _client
        .from('businesses')
        .select('id, name, business_type')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    if (businesses.isEmpty) return const [];

    final businessData = <String, Map<String, dynamic>>{
      for (final business in businesses) business['id'] as String: business,
    };
    final submissions = await _client
        .from('business_verification_submissions')
        .select('business_id, contact_name, contact_email')
        .inFilter('business_id', businessData.keys.toList())
        .eq('status', 'pending');

    return submissions.map((submission) {
      final business = businessData[submission['business_id'] as String]!;
      return PendingBusinessSubmission(
        businessId: business['id'] as String,
        name: business['name'] as String,
        businessType: (business['business_type'] as String?) ?? 'Business',
        contactName: submission['contact_name'] as String,
        contactEmail: submission['contact_email'] as String,
      );
    }).toList();
  }

  static Future<void> reviewSubmission({
    required String businessId,
    required bool approved,
  }) async {
    await _client
        .from('businesses')
        .update({
          'status': approved ? 'approved' : 'rejected',
          'verification_status': approved ? 'verified' : 'rejected',
        })
        .eq('id', businessId);
    await _client
        .from('business_verification_submissions')
        .update({'status': approved ? 'approved' : 'rejected'})
        .eq('business_id', businessId)
        .eq('status', 'pending');
  }

  static Future<List<OwnedBusiness>> fetchMyBusinesses() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    try {
      final rows = await _client
          .from('businesses')
          .select('id, name, business_type, status, description, services')
          .eq('created_by', user.id)
          .order('created_at', ascending: false);
      if (rows.isNotEmpty) {
        return rows.map(_ownedBusinessFromRow).toList();
      }

      final submissions = await _client
          .from('business_verification_submissions')
          .select(
            'business_id, businesses(id, name, business_type, status, description, services)',
          )
          .eq('submitter_id', user.id)
          .order('created_at', ascending: false);
      final seen = <String>{};
      final businesses = <OwnedBusiness>[];
      for (final submission in submissions) {
        final business = submission['businesses'];
        if (business is! Map) continue;
        final id = business['id'] as String?;
        if (id == null || seen.contains(id)) continue;
        seen.add(id);
        businesses.add(
          _ownedBusinessFromRow(Map<String, dynamic>.from(business)),
        );
      }
      return businesses;
    } catch (error) {
      throw StateError('Unable to load your businesses: $error');
    }
  }

  static OwnedBusiness _ownedBusinessFromRow(Map<String, dynamic> row) {
    return OwnedBusiness(
      id: row['id'] as String,
      name: row['name'] as String,
      businessType: (row['business_type'] as String?) ?? 'Service business',
      status: (row['status'] as String?) ?? 'pending',
      description: (row['description'] as String?) ?? '',
      services: List<String>.from((row['services'] as List?) ?? const []),
    );
  }

  static Future<Map<String, String>> fetchLocation(String businessId) async {
    try {
      final row = await _client
          .from('business_locations')
          .select(
            'address_line_1, address_line_2, city, state, postal_code, '
            'country_code, formatted_address, place_id, latitude, longitude',
          )
          .eq('business_id', businessId)
          .maybeSingle();
      return {
        'address': (row?['address_line_1'] as String?) ?? '',
        'address_line_2': (row?['address_line_2'] as String?) ?? '',
        'city': (row?['city'] as String?) ?? '',
        'state': (row?['state'] as String?) ?? '',
        'zip': (row?['postal_code'] as String?) ?? '',
        'country': (row?['country_code'] as String?) ?? 'US',
        'formatted_address': (row?['formatted_address'] as String?) ?? '',
        'place_id': (row?['place_id'] as String?) ?? '',
        'latitude': row?['latitude']?.toString() ?? '',
        'longitude': row?['longitude']?.toString() ?? '',
      };
    } catch (_) {
      try {
        final row = await _client
            .from('business_locations')
            .select('address_line_1, city, state, postal_code')
            .eq('business_id', businessId)
            .maybeSingle();
        return {
          'address': (row?['address_line_1'] as String?) ?? '',
          'address_line_2': '',
          'city': (row?['city'] as String?) ?? '',
          'state': (row?['state'] as String?) ?? '',
          'zip': (row?['postal_code'] as String?) ?? '',
          'country': 'US',
          'formatted_address': '',
          'place_id': '',
          'latitude': '',
          'longitude': '',
        };
      } catch (_) {
        return {
          'address': '',
          'address_line_2': '',
          'city': '',
          'state': '',
          'zip': '',
          'country': 'US',
          'formatted_address': '',
          'place_id': '',
          'latitude': '',
          'longitude': '',
        };
      }
    }
  }

  static Future<void> saveBusinessProfile({
    required OwnedBusiness business,
    required String description,
    required String services,
    required String address,
    required String city,
    required String state,
    required String zip,
    bool comingSoon = false,
    String? addressLine2,
    String? formattedAddress,
    String? placeId,
    double? latitude,
    double? longitude,
    String countryCode = 'US',
  }) async {
    final serviceList = services
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    await _client
        .from('businesses')
        .update({
          'description': description,
          'services': serviceList,
          'coming_soon': comingSoon,
        })
        .eq('id', business.id);
    final existing = await _client
        .from('business_locations')
        .select('id')
        .eq('business_id', business.id)
        .maybeSingle();
    final baseLocation = {
      'address_line_1': address,
      'city': city,
      'state': state.toUpperCase(),
      'postal_code': zip,
    };
    final extendedLocation = {
      ...baseLocation,
      'address_line_2': addressLine2?.trim().isEmpty == true
          ? null
          : addressLine2?.trim(),
      'formatted_address': formattedAddress?.trim().isEmpty == true
          ? null
          : formattedAddress?.trim(),
      'place_id': placeId?.trim().isEmpty == true ? null : placeId?.trim(),
      'country_code': countryCode.trim().isEmpty ? 'US' : countryCode.trim(),
      'latitude': ?latitude,
      'longitude': ?longitude,
    };

    Future<void> write(Map<String, dynamic> location) async {
      if (existing == null) {
        await _client.from('business_locations').insert({
          ...location,
          'business_id': business.id,
        });
      } else {
        await _client
            .from('business_locations')
            .update(location)
            .eq('id', existing['id'] as String);
      }
    }

    try {
      await write(extendedLocation);
    } catch (_) {
      // Graceful fallback when Phase 4 address columns are not migrated yet.
      await write(baseLocation);
    }
  }

  static Future<bool> fetchComingSoon(String businessId) async {
    try {
      final row = await _client
          .from('businesses')
          .select('coming_soon')
          .eq('id', businessId)
          .maybeSingle();
      return (row?['coming_soon'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
