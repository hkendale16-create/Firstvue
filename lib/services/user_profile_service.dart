import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String? displayName;
  final String? username;
  final String? bio;
  final String? city;
  final String? state;
  final String? website;

  const UserProfile({
    required this.id,
    this.displayName,
    this.username,
    this.bio,
    this.city,
    this.state,
    this.website,
  });

  String? get locationLabel {
    final parts = [city, state].whereType<String>().where((p) => p.trim().isNotEmpty);
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

    const fullColumns =
        'id, display_name, username, bio, city, state, website';
    const baseColumns = 'id, display_name, username, bio, city, state';

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('profiles')
          .select(fullColumns)
          .eq('id', profileId)
          .maybeSingle();
    } catch (_) {
      try {
        row = await _client
            .from('profiles')
            .select(baseColumns)
            .eq('id', profileId)
            .maybeSingle();
      } catch (_) {
        return null;
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
    );
  }

  /// Same length/character rules as @handles, but duplicates are allowed.
  static String? displayNameValidationMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Display name cannot be empty.';
    }
    final normalized = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
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

    await _upsertProfile(user.id, updates);
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
}
