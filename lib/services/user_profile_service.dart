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

    try {
      final row = await _client
          .from('profiles')
          .select('id, display_name, username, bio, city, state, website')
          .eq('id', profileId)
          .maybeSingle();
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
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateDisplayName(String displayName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to update your profile.');
    }

    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
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
      if (trimmed.isEmpty) {
        throw ArgumentError('Display name cannot be empty.');
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
    try {
      if (fields.containsKey('display_name')) {
        await _client.rpc(
          'ensure_user_profile',
          params: {'display_name': fields['display_name']},
        );
        final rest = Map<String, dynamic>.from(fields)..remove('display_name');
        if (rest.length > 1) {
          await _client.from('profiles').update(rest).eq('id', userId);
        }
        return;
      }
    } catch (_) {}

    await _client.from('profiles').upsert({
      'id': userId,
      ...fields,
    });
  }
}
