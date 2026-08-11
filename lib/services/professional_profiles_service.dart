import 'package:supabase_flutter/supabase_flutter.dart';

enum ProfessionalType {
  barber('barber', 'Barber'),
  stylist('stylist', 'Stylist'),
  beautyProfessional('beauty_professional', 'Beauty Professional');

  final String value;
  final String label;

  const ProfessionalType(this.value, this.label);

  static ProfessionalType fromValue(String value) {
    return values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProfessionalType.beautyProfessional,
    );
  }
}

class ProfessionalProfile {
  final String id;
  final String profileId;
  final String displayName;
  final ProfessionalType type;
  final String bio;
  final String city;
  final String state;
  final String postalCode;
  final List<String> services;
  final bool acceptsNewClients;
  final String availabilityNote;
  final String bookingUrl;
  final String status;
  final DateTime? createdAt;

  const ProfessionalProfile({
    required this.id,
    required this.profileId,
    required this.displayName,
    required this.type,
    required this.bio,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.services,
    required this.acceptsNewClients,
    required this.availabilityNote,
    required this.bookingUrl,
    required this.status,
    this.createdAt,
  });

  factory ProfessionalProfile.fromMap(Map<String, dynamic> map) {
    return ProfessionalProfile(
      id: map['id'] as String,
      profileId: map['profile_id'] as String,
      displayName: (map['display_name'] as String?) ?? 'Professional',
      type: ProfessionalType.fromValue(
        (map['professional_type'] as String?) ?? '',
      ),
      bio: (map['bio'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      state: (map['state'] as String?) ?? '',
      postalCode: (map['postal_code'] as String?) ?? '',
      services: ((map['services'] as List?) ?? const [])
          .map((service) => service.toString())
          .toList(),
      acceptsNewClients: (map['accepts_new_clients'] as bool?) ?? true,
      availabilityNote: (map['availability_note'] as String?) ?? '',
      bookingUrl: (map['booking_url'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pending',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
    );
  }
}

class ProfessionalProfilesService {
  ProfessionalProfilesService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Stream<List<ProfessionalProfile>> watchApproved(
    ProfessionalType type,
  ) {
    return _client
        .from('professional_profiles')
        .stream(primaryKey: ['id'])
        .eq('professional_type', type.value)
        .eq('status', 'approved')
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ProfessionalProfile.fromMap).toList());
  }

  static Future<ProfessionalProfile?> fetchMine() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('professional_profiles')
        .select()
        .eq('profile_id', user.id)
        .maybeSingle();
    return row == null ? null : ProfessionalProfile.fromMap(row);
  }

  static Future<void> saveMine({
    required String displayName,
    required ProfessionalType type,
    required String bio,
    required String city,
    required String state,
    required String postalCode,
    required List<String> services,
    required bool acceptsNewClients,
    required String availabilityNote,
    required String bookingUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to create a professional profile.');
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'account_type': 'professional',
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _client.from('professional_profiles').upsert({
      'profile_id': user.id,
      'display_name': displayName,
      'professional_type': type.value,
      'bio': bio,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'services': services,
      'accepts_new_clients': acceptsNewClients,
      'availability_note': availabilityNote,
      'booking_url': bookingUrl,
      'status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'profile_id');
  }

  static Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .maybeSingle();
    return row?['account_type'] == 'admin';
  }

  static Future<List<ProfessionalProfile>> fetchPending() async {
    final rows = await _client
        .from('professional_profiles')
        .select()
        .eq('status', 'pending')
        .order('created_at');
    return rows.map(ProfessionalProfile.fromMap).toList();
  }

  static Future<void> moderate(String id, String status) async {
    if (status != 'approved' && status != 'rejected') {
      throw ArgumentError.value(status, 'status');
    }
    await _client
        .from('professional_profiles')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
