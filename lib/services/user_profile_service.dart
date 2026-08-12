import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileService {
  UserProfileService._();

  static final _client = Supabase.instance.client;

  static Future<String?> fetchDisplayName() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      return row?['display_name'] as String?;
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

    try {
      await _client.rpc(
        'ensure_user_profile',
        params: {'display_name': trimmed},
      );
    } catch (_) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': trimmed,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }
}
