import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizerApplication {
  final String id;
  final String profileId;
  final String displayName;
  final String? organizationName;
  final String? reason;
  final DateTime createdAt;

  const OrganizerApplication({
    required this.id,
    required this.profileId,
    required this.displayName,
    required this.organizationName,
    required this.reason,
    required this.createdAt,
  });
}

class OrganizerApplicationService {
  OrganizerApplicationService._();

  static final _client = Supabase.instance.client;

  static Future<void> submit({
    required String displayName,
    String? organizationName,
    String? reason,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sign in to apply.');

    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': displayName,
      'account_type': 'customer',
      'updated_at': DateTime.now().toIso8601String(),
    });

    await _client.from('community_organizer_applications').insert({
      'profile_id': user.id,
      'display_name': displayName.trim(),
      'organization_name': organizationName?.trim(),
      'reason': reason?.trim(),
      'status': 'pending',
    });
  }

  static Future<List<OrganizerApplication>> fetchPending() async {
    final rows = await _client
        .from('community_organizer_applications')
        .select('id, profile_id, display_name, organization_name, reason, created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows
        .map(
          (row) => OrganizerApplication(
            id: row['id'] as String,
            profileId: row['profile_id'] as String,
            displayName: row['display_name'] as String,
            organizationName: row['organization_name'] as String?,
            reason: row['reason'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  static Future<void> review({
    required String applicationId,
    required String profileId,
    required bool approved,
  }) async {
    try {
      await _client.rpc(
        'review_organizer_application',
        params: {
          'p_application_id': applicationId,
          'p_approve': approved,
        },
      );
      return;
    } catch (_) {
      // Fallback for projects that have not applied 20261009 yet.
    }

    await _client
        .from('community_organizer_applications')
        .update({'status': approved ? 'approved' : 'rejected'})
        .eq('id', applicationId);
    if (approved) {
      await _client.from('community_organizers').upsert({
        'profile_id': profileId,
        'approved_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
