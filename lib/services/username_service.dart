import 'package:supabase_flutter/supabase_flutter.dart';

enum UsernameAvailability {
  empty,
  invalid,
  checking,
  available,
  taken,
  error,
}

class UsernameService {
  UsernameService._();

  static final _client = Supabase.instance.client;
  static final _validPattern = RegExp(r'^[a-z0-9_]{3,30}$');

  /// True when [query] is an @handle search (trimmed text starts with `@`).
  static bool isUsernameQuery(String query) => query.trim().startsWith('@');

  /// Prefix for @handle autocomplete (1–30 chars). Strips `@` and invalid chars.
  /// Unlike [normalize], partial prefixes like `jo` from `@jo` are allowed.
  static String? autocompletePrefix(String raw) {
    var cleaned = raw.trim();
    if (!cleaned.startsWith('@')) return null;
    while (cleaned.startsWith('@')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (cleaned.isEmpty || cleaned.length > 30) return null;
    return cleaned;
  }

  /// Lowercase alphanumeric + underscore, 3–30 chars. Strips a leading @.
  static String? normalize(String raw) {
    var cleaned = raw.trim();
    while (cleaned.startsWith('@')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (cleaned.length < 3 || cleaned.length > 30) return null;
    return cleaned;
  }

  static bool isValid(String username) => _validPattern.hasMatch(username);

  static String? validationMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Choose a unique @handle for your profile.';
    }
    final normalized = normalize(raw);
    if (normalized == null) {
      return 'Usernames must be 3–30 characters using lowercase letters, numbers, and underscores.';
    }
    return null;
  }

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

  static Future<bool> isAvailable(String username) async {
    final normalized = normalize(username);
    if (normalized == null) return false;

    try {
      final result = await _client.rpc(
        'is_username_available',
        params: {'candidate': normalized},
      );
      return result == true;
    } catch (_) {
      return false;
    }
  }

  static Future<UsernameAvailability> checkAvailability(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return UsernameAvailability.empty;

    final normalized = normalize(raw);
    if (normalized == null) return UsernameAvailability.invalid;

    try {
      final available = await isAvailable(normalized);
      return available ? UsernameAvailability.available : UsernameAvailability.taken;
    } catch (_) {
      return UsernameAvailability.error;
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

  static Future<String> updateUsername(String username) async {
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

    try {
      final result = await _client.rpc(
        'set_profile_username',
        params: {'candidate': normalized},
      );
      return (result as String?) ?? normalized;
    } on PostgrestException catch (error) {
      final message = error.message.trim();
      if (message.toLowerCase().contains('already taken') ||
          error.code == '23505') {
        throw ArgumentError('That @handle is already taken. Choose another one.');
      }
      if (message.isNotEmpty) {
        throw ArgumentError(message);
      }
      rethrow;
    }
  }
}
