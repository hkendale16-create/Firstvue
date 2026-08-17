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
      throw AuthException(_friendlyBusinessError(error));
    }
  }

  /// Permanently deletes an individual professional profile
  /// (`public.professional_profiles`). Owner only.
  static Future<void> deleteOwnedProfessional(
    String professionalProfileId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete this profile.');
    }
    try {
      await _client.rpc(
        'delete_owned_professional',
        params: {'p_professional_profile_id': professionalProfileId},
      );
    } on PostgrestException catch (error) {
      throw AuthException(_friendlyProfessionalError(error));
    }
  }

  /// Permanently deletes a Group (`public.communities`). Owner/creator only.
  static Future<void> deleteOwnedGroup(String groupId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete this group.');
    }
    try {
      await _client.rpc(
        'delete_owned_group',
        params: {'p_group_id': groupId},
      );
    } on PostgrestException catch (error) {
      throw AuthException(_friendlyGroupError(error));
    }
  }

  /// Permanently deletes a Community hub. Creator/leader only.
  /// Linked Groups are unlinked, not deleted.
  static Future<void> deleteOwnedCommunityHub(String hubId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete this community.');
    }
    try {
      await _client.rpc(
        'delete_owned_community_hub',
        params: {'p_hub_id': hubId},
      );
    } on PostgrestException catch (error) {
      throw AuthException(_friendlyHubError(error));
    }
  }

  static String _friendlyBusinessError(PostgrestException error) {
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

  static String _friendlyProfessionalError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('only the owner')) {
      return 'Only the owner can permanently delete this professional profile.';
    }
    if (message.contains('not found')) {
      return 'This professional profile could not be found.';
    }
    if (message.contains('authentication')) {
      return 'Please sign in again to confirm deletion.';
    }
    return 'Could not delete this professional profile. ${error.message}';
  }

  static String _friendlyGroupError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('only the group owner') ||
        message.contains('only the owner')) {
      return 'Only the group owner or creator can permanently delete this group.';
    }
    if (message.contains('not found')) {
      return 'This group could not be found.';
    }
    if (message.contains('authentication')) {
      return 'Please sign in again to confirm deletion.';
    }
    return 'Could not delete this group. ${error.message}';
  }

  static String _friendlyHubError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('only the community creator') ||
        message.contains('only the owner')) {
      return 'Only the community creator or leader can permanently delete this community.';
    }
    if (message.contains('not found')) {
      return 'This community could not be found.';
    }
    if (message.contains('authentication')) {
      return 'Please sign in again to confirm deletion.';
    }
    return 'Could not delete this community. ${error.message}';
  }
}
