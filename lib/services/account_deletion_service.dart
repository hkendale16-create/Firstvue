import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionBlocker {
  final String id;
  final String label;

  const AccountDeletionBlocker({required this.id, required this.label});
}

class AccountDeletionBlockers {
  final bool blocked;
  final List<AccountDeletionBlocker> businesses;
  final List<AccountDeletionBlocker> communityHubs;
  final List<AccountDeletionBlocker> rentalListings;
  final String? message;

  const AccountDeletionBlockers({
    required this.blocked,
    this.businesses = const [],
    this.communityHubs = const [],
    this.rentalListings = const [],
    this.message,
  });

  factory AccountDeletionBlockers.fromJson(Map<String, dynamic> json) {
    List<AccountDeletionBlocker> parseList(
      String key,
      String labelKey,
    ) {
      final raw = json[key];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            AccountDeletionBlocker(
              id: item['id']?.toString() ?? '',
              label: item[labelKey]?.toString() ?? 'Unknown',
            ),
      ];
    }

    return AccountDeletionBlockers(
      blocked: json['blocked'] == true,
      businesses: parseList('businesses', 'name'),
      communityHubs: parseList('community_hubs', 'name'),
      rentalListings: parseList('rental_listings', 'title'),
      message: json['message'] as String?,
    );
  }
}

class AccountDeletionException implements Exception {
  final String message;
  final AccountDeletionBlockers? blockers;

  const AccountDeletionException(this.message, {this.blockers});

  @override
  String toString() => message;
}

class AccountDeletionService {
  AccountDeletionService._();

  static final _client = Supabase.instance.client;

  static Future<AccountDeletionBlockers> fetchBlockers() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete your account.');
    }

    final result = await _client.rpc('get_account_deletion_blockers');
    if (result is Map<String, dynamic>) {
      return AccountDeletionBlockers.fromJson(result);
    }
    if (result is Map) {
      return AccountDeletionBlockers.fromJson(result.cast<String, dynamic>());
    }
    return const AccountDeletionBlockers(blocked: false);
  }

  /// Deletes the signed-in account.
  ///
  /// Prefers Edge Function `delete-account` when deployed; otherwise uses
  /// SQL RPC `delete_my_account` (no Edge Function required).
  static Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete your account.');
    }

    // 1) Prefer Edge Function when available.
    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: const {},
      );
      if (response.status == 200) {
        await _client.auth.signOut();
        return;
      }
      if (response.status != 404) {
        final data = response.data;
        if (data is Map) {
          final blockersRaw = data['blockers'];
          AccountDeletionBlockers? blockers;
          if (blockersRaw is Map) {
            blockers = AccountDeletionBlockers.fromJson(
              blockersRaw.cast<String, dynamic>(),
            );
          }
          throw AccountDeletionException(
            data['error']?.toString() ??
                'Unable to delete your account right now.',
            blockers: blockers,
          );
        }
        throw AccountDeletionException(
          'Unable to delete your account (${response.status}).',
        );
      }
    } on FunctionException catch (error) {
      if (error.status != 404) {
        throw AccountDeletionException(
          error.details?.toString() ??
              error.reasonPhrase ??
              'Unable to delete your account right now.',
        );
      }
      // Fall through to SQL path when function is not deployed.
    } on AccountDeletionException {
      rethrow;
    } catch (_) {
      // Fall through to SQL path on network / missing-function errors.
    }

    // 2) SQL self-delete RPC (works without Edge Functions).
    final result = await _client.rpc('delete_my_account');
    Map<String, dynamic>? map;
    if (result is Map<String, dynamic>) {
      map = result;
    } else if (result is Map) {
      map = result.cast<String, dynamic>();
    }

    if (map != null && map['blocked'] == true) {
      throw AccountDeletionException(
        map['message']?.toString() ??
            'Transfer or delete your businesses and communities first.',
        blockers: AccountDeletionBlockers.fromJson(map),
      );
    }

    if (map != null && map['deleted'] == true) {
      await _client.auth.signOut();
      return;
    }

    throw const AccountDeletionException(
      'Unable to delete your account right now.',
    );
  }
}
