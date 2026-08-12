import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_identity.dart';
import 'user_profile_service.dart';

class PostIdentityService {
  PostIdentityService._();

  static final _client = Supabase.instance.client;

  static Future<List<PostIdentityOption>> fetchOptions() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    final profile = await UserProfileService.fetchProfile();
    final displayName =
        profile?.displayName?.trim().isNotEmpty == true
            ? profile!.displayName!.trim()
            : (user.email?.split('@').first ?? 'You');

    final options = <PostIdentityOption>[
      PostIdentityOption.personal(displayName: displayName),
    ];

    try {
      final businesses = await _client
          .from('businesses')
          .select('id, name')
          .eq('created_by', user.id)
          .eq('status', 'approved')
          .order('name')
          .limit(20);

      for (final row in businesses) {
        options.add(
          PostIdentityOption(
            kind: PostIdentityKind.business,
            businessId: row['id'] as String,
            label: row['name'] as String,
            subtitle: 'Business',
          ),
        );
      }
    } catch (_) {}

    try {
      final memberships = await _client
          .from('community_members')
          .select('community_id, communities(id, name, city, state)')
          .eq('profile_id', user.id)
          .eq('status', 'active')
          .limit(20);

      for (final row in memberships) {
        final community = row['communities'] as Map<String, dynamic>?;
        if (community == null) continue;
        final city = community['city'] as String?;
        final state = community['state'] as String?;
        final location = [city, state]
            .whereType<String>()
            .where((p) => p.trim().isNotEmpty)
            .join(', ');

        options.add(
          PostIdentityOption(
            kind: PostIdentityKind.community,
            communityId: community['id'] as String,
            label: community['name'] as String,
            subtitle: location.isEmpty ? 'Community' : location,
          ),
        );
      }
    } catch (_) {}

    return options;
  }
}
