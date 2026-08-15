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

  static Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to delete your account.');
    }

    final response = await _client.functions.invoke(
      'delete-account',
      body: const {},
    );

    if (response.status == 200) {
      return;
    }

    final data = response.data;
    if (data is Map) {
      final blockersRaw = data['blockers'];
      AccountDeletionBlockers? blockers;
      if (blockersRaw is Map) {
        blockers = AccountDeletionBlockers.fromJson(
          blockersRaw.cast<String, dynamic>(),
        );
      }
      final message = data['error']?.toString() ??
          'Unable to delete your account right now.';
      throw AccountDeletionException(message, blockers: blockers);
    }

    throw AccountDeletionException(
      'Unable to delete your account (${response.status}).',
    );
  }
}
