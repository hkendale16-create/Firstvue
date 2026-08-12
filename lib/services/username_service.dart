import 'package:supabase_flutter/supabase_flutter.dart';

class UsernameService {
  UsernameService._();

  static final _client = Supabase.instance.client;
  static final _validPattern = RegExp(r'^[a-z0-9_]{3,30}$');

  /// Lowercase alphanumeric + underscore, 3–30 chars.
  static String? normalize(String raw) {
    final cleaned = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (cleaned.length < 3 || cleaned.length > 30) return null;
    return cleaned;
  }

  static bool isValid(String username) => _validPattern.hasMatch(username);

  static Future<String?> fetchUsername() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return fetchUsernameForUser(user.id);
  }

  static Future<String?> fetchUsernameForUser(String profileId) async {
    if (profileId.trim().isEmpty) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('username')
          .eq('id', profileId)
          .maybeSingle();
      final username = row?['username'] as String?;
      if (username == null || username.trim().isEmpty) return null;
      return username.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isAvailable(String username, {String? excludeUserId}) async {
    final normalized = normalize(username);
    if (normalized == null) return false;

    try {
      var query = _client
          .from('profiles')
          .select('id')
          .eq('username', normalized);
      if (excludeUserId != null) {
        query = query.neq('id', excludeUserId);
      }
      final row = await query.maybeSingle();
      return row == null;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> lookupProfileId(String username) async {
    final normalized = normalize(username);
    if (normalized == null) return null;
    try {
      final row = await _client
          .from('profiles')
          .select('id')
          .eq('username', normalized)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateUsername(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to update your username.');
    }

    final normalized = normalize(username);
    if (normalized == null) {
      throw ArgumentError(
        'Username must be 3–30 characters: lowercase letters, numbers, and underscores only.',
      );
    }

    final available = await isAvailable(normalized, excludeUserId: user.id);
    if (!available) {
      throw ArgumentError('That username is already taken.');
    }

    await _client.from('profiles').upsert({
      'id': user.id,
      'username': normalized,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
