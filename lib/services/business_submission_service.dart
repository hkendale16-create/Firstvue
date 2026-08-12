import 'package:supabase_flutter/supabase_flutter.dart';

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

  static Future<void> submitNewBusiness({
    required String name,
    required String businessType,
    required String contactName,
    required String contactEmail,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in before submitting a business.');
    }

    final business = await _client
        .from('businesses')
        .insert({
          'name': name,
          'business_type': businessType,
          'created_by': user.id,
          'status': 'pending',
          'verification_status': 'pending',
        })
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
    } catch (_) {
      await _client.from('businesses').delete().eq('id', businessId);
      rethrow;
    }
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
    final rows = await _client
        .from('businesses')
        .select('id, name, business_type, status, description, services')
        .eq('created_by', user.id)
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => OwnedBusiness(
            id: row['id'] as String,
            name: row['name'] as String,
            businessType:
                (row['business_type'] as String?) ?? 'Service business',
            status: row['status'] as String,
            description: (row['description'] as String?) ?? '',
            services: List<String>.from((row['services'] as List?) ?? const []),
          ),
        )
        .toList();
  }

  static Future<Map<String, String>> fetchLocation(String businessId) async {
    final row = await _client
        .from('business_locations')
        .select('address_line_1, city, state, postal_code')
        .eq('business_id', businessId)
        .maybeSingle();
    return {
      'address': (row?['address_line_1'] as String?) ?? '',
      'city': (row?['city'] as String?) ?? '',
      'state': (row?['state'] as String?) ?? '',
      'zip': (row?['postal_code'] as String?) ?? '',
    };
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
  }) async {
    final serviceList = services
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    await _client.from('businesses').update({
      'description': description,
      'services': serviceList,
      'coming_soon': comingSoon,
    }).eq('id', business.id);
    final existing = await _client
        .from('business_locations')
        .select('id')
        .eq('business_id', business.id)
        .maybeSingle();
    final location = {
      'address_line_1': address,
      'city': city,
      'state': state.toUpperCase(),
      'postal_code': zip,
    };
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
