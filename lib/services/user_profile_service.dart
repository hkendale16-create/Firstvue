import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String? displayName;
  final String? username;
  final String? bio;
  final String? city;
  final String? state;
  final String? website;
  final String? phone;
  final DateTime? birthday;
  final bool? isPrivate;
  final String? profileVisibility;
  final bool? showEmailOnProfile;
  final Map<String, String>? fieldVisibility;

  const UserProfile({
    required this.id,
    this.displayName,
    this.username,
    this.bio,
    this.city,
    this.state,
    this.website,
    this.phone,
    this.birthday,
    this.isPrivate,
    this.profileVisibility,
    this.showEmailOnProfile,
    this.fieldVisibility,
  });

  String? get locationLabel {
    final parts =
        [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

class UserProfileService {
  UserProfileService._();

  static final _client = Supabase.instance.client;

  static Future<String?> fetchDisplayName() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return fetchDisplayNameForUser(user.id);
  }

  static Future<String?> fetchDisplayNameForUser(String profileId) async {
    if (profileId.trim().isEmpty) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', profileId)
          .maybeSingle();
      return row?['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<UserProfile?> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return fetchProfileForUser(user.id);
  }

  static Future<UserProfile?> fetchProfileForUser(String profileId) async {
    if (profileId.trim().isEmpty) return null;

    const columnSets = <String>[
      'id, display_name, username, bio, city, state, website, phone, birthday, '
          'is_private, profile_visibility, show_email_on_profile, field_visibility',
      'id, display_name, username, bio, city, state, website, phone, birthday, '
          'is_private, profile_visibility, field_visibility',
      'id, display_name, username, bio, city, state, website, '
          'is_private, profile_visibility',
      'id, display_name, username, bio, city, state, website',
      'id, display_name, username, bio, city, state',
    ];

    Map<String, dynamic>? row;
    for (final columns in columnSets) {
      try {
        row = await _client
            .from('profiles')
            .select(columns)
            .eq('id', profileId)
            .maybeSingle();
        break;
      } catch (_) {
        row = null;
      }
    }

    if (row == null) return null;

    return UserProfile(
      id: row['id'] as String,
      displayName: row['display_name'] as String?,
      username: row['username'] as String?,
      bio: row['bio'] as String?,
      city: row['city'] as String?,
      state: row['state'] as String?,
      website: row['website'] as String?,
      phone: row['phone'] as String?,
      birthday: _parseDate(row['birthday']),
      isPrivate: row['is_private'] as bool?,
      profileVisibility: row['profile_visibility'] as String?,
      showEmailOnProfile: row['show_email_on_profile'] as bool?,
      fieldVisibility: _parseFieldVisibility(row['field_visibility']),
    );
  }

  /// Same length/character rules as @handles, but duplicates are allowed.
  static String? displayNameValidationMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Display name cannot be empty.';
    }
    final normalized =
        trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (normalized.length < 3 || normalized.length > 30) {
      return 'Display names must be 3–30 characters using letters, numbers, and underscores.';
    }
    return null;
  }

  static Future<void> updateDisplayName(String displayName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to update your profile.');
    }

    final trimmed = displayName.trim();
    final validationError = displayNameValidationMessage(trimmed);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    await _upsertProfile(user.id, {'display_name': trimmed});
  }

  static Future<void> updateExtendedProfile({
    String? displayName,
    String? bio,
    String? city,
    String? state,
    String? website,
    String? phone,
    DateTime? birthday,
    bool clearBirthday = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to update your profile.');
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (displayName != null) {
      final trimmed = displayName.trim();
      final validationError = displayNameValidationMessage(trimmed);
      if (validationError != null) {
        throw ArgumentError(validationError);
      }
      updates['display_name'] = trimmed;
    }

    if (bio != null) {
      updates['bio'] = bio.trim().isEmpty ? null : bio.trim();
    }

    if (city != null) {
      updates['city'] = city.trim().isEmpty ? null : city.trim();
    }

    if (state != null) {
      updates['state'] = state.trim().isEmpty ? null : state.trim();
    }

    if (website != null) {
      updates['website'] = website.trim().isEmpty ? null : website.trim();
    }

    final withPhone = Map<String, dynamic>.from(updates);
    if (phone != null) {
      withPhone['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }
    if (clearBirthday) {
      withPhone['birthday'] = null;
    } else if (birthday != null) {
      withPhone['birthday'] = birthday.toIso8601String().split('T').first;
    }

    try {
      await _upsertProfile(user.id, withPhone);
    } catch (_) {
      // phone / birthday columns may be missing pre-migration.
      await _upsertProfile(user.id, updates);
    }
  }

  static Future<void> _upsertProfile(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    await _client.from('profiles').upsert({
      'id': userId,
      ...fields,
    });
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static Map<String, String>? _parseFieldVisibility(dynamic raw) {
    if (raw == null) return null;
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((key, value) {
      if (key == null) return;
      out[key.toString()] = (value?.toString() ?? '').trim();
    });
    return out;
  }
}
