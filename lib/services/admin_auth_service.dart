import 'package:supabase_flutter/supabase_flutter.dart';

/// Central admin authorization for FirstVue.
///
/// Server truth lives in Supabase:
/// - JWT `app_metadata.firstvue_admin = true` (preferred), or
/// - `profiles.account_type = 'admin'` (set only via Dashboard/SQL).
class AdminAuthService {
  AdminAuthService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool get isSignedIn => _client.auth.currentUser != null;

  static bool get hasJwtAdminClaim {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final appMetadata = user.appMetadata;
    if (appMetadata['firstvue_admin'] == true) return true;
    if (appMetadata['role'] == 'admin') return true;
    return false;
  }

  static Future<bool> isAdmin() async {
    if (!isSignedIn) return false;
    if (hasJwtAdminClaim) return true;

    final user = _client.auth.currentUser!;
    final profile = await _client
        .from('profiles')
        .select('account_type')
        .eq('id', user.id)
        .maybeSingle();

    return profile?['account_type'] == 'admin';
  }
}
