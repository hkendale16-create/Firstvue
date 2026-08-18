import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_auth_service.dart';

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
  final String? addressLine1;
  final double? latitude;
  final double? longitude;
  final String? placeId;

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
    this.addressLine1,
    this.latitude,
    this.longitude,
    this.placeId,
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
      addressLine1: map['address_line_1'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      placeId: map['place_id'] as String?,
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

  static Future<ProfessionalProfile?> fetchById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final row = await _client
          .from('professional_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : ProfessionalProfile.fromMap(row);
    } catch (_) {
      return null;
    }
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
    String? addressLine1,
    double? latitude,
    double? longitude,
    String? placeId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to create a professional profile.');
    }

    final trimmedAddress = addressLine1?.trim();
    final trimmedPlaceId = placeId?.trim();
    final now = DateTime.now().toIso8601String();

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName,
        'updated_at': now,
      });
    } catch (_) {}

    try {
      await _client.from('profiles').update({
        'account_type': 'professional',
        'updated_at': now,
      }).eq('id', user.id);
    } catch (_) {}

    final core = <String, dynamic>{
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
      'updated_at': now,
    };
    final withAddress = <String, dynamic>{
      ...core,
      if (trimmedAddress != null && trimmedAddress.isNotEmpty)
        'address_line_1': trimmedAddress,
      'latitude': ?latitude,
      'longitude': ?longitude,
      if (trimmedPlaceId != null && trimmedPlaceId.isNotEmpty)
        'place_id': trimmedPlaceId,
    };

    try {
      await _upsertProfessional(withAddress);
    } on PostgrestException catch (error) {
      if (_isUnknownColumn(error)) {
        await _upsertProfessional(core);
        return;
      }
      try {
        final existing = await fetchMine();
        if (existing != null) {
          await _client
              .from('professional_profiles')
              .update(withAddress)
              .eq('profile_id', user.id);
        } else {
          await _client.from('professional_profiles').insert(withAddress);
        }
      } catch (retryError) {
        throw StateError(_friendlySaveError(retryError, fallback: error));
      }
    }
  }

  static Future<void> _upsertProfessional(Map<String, dynamic> row) {
    return _client.from('professional_profiles').upsert(
      row,
      onConflict: 'profile_id',
    );
  }

  static bool _isUnknownColumn(PostgrestException error) {
    final text = '${error.message} ${error.details ?? ''}'.toLowerCase();
    return text.contains('does not exist') ||
        text.contains('schema cache') ||
        (text.contains('could not find the') && text.contains('column'));
  }

  static String _friendlySaveError(
    Object error, {
    PostgrestException? fallback,
  }) {
    final source = error is PostgrestException ? error : fallback;
    final message = (source?.message ?? error.toString()).toLowerCase();
    if (message.contains('sign in') || message.contains('jwt')) {
      return 'Sign in again to save your professional profile.';
    }
    if (message.contains('row-level security') ||
        message.contains('violates row-level') ||
        message.contains('42501')) {
      return 'This profile cannot be updated right now. If it is already '
          'approved, wait for review after resubmitting.';
    }
    if (message.contains('display_name') && message.contains('check')) {
      return 'Use a display name between 2 and 120 characters.';
    }
    if (message.contains('duplicate') || message.contains('unique')) {
      return 'A professional profile already exists for this account.';
    }
    if (source?.message != null && source!.message.trim().isNotEmpty) {
      return 'Unable to save your profile. ${source.message}';
    }
    return 'Unable to save your profile. Please try again.';
  }

  static Future<bool> isAdmin() => AdminAuthService.isAdmin();

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
