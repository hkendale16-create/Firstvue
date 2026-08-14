import 'package:supabase_flutter/supabase_flutter.dart';

/// Owner-only permanent entity deletion. Never call against production
/// records during development.
class EntityDeletionService {
  EntityDeletionService._();

  static final _client = Supabase.instance.client;

  static Future<void> deleteOwnedBusiness(String businessId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete this business.');
    }
    try {
      await _client.rpc(
        'delete_owned_business',
        params: {'p_business_id': businessId},
      );
    } on PostgrestException catch (error) {
      throw AuthException(_friendlyError(error));
    }
  }

  static String _friendlyError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('only the owner')) {
      return 'Only the owner can permanently delete this business.';
    }
    if (message.contains('not found')) {
      return 'This business could not be found.';
    }
    if (message.contains('authentication')) {
      return 'Please sign in again to confirm deletion.';
    }
    return 'Could not delete this business. ${error.message}';
  }
}
