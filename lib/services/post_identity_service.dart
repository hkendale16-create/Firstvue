import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post_identity.dart';
import 'community_service.dart';
import 'user_profile_service.dart';

class PostIdentityService {
  PostIdentityService._();

  static final _client = Supabase.instance.client;

  /// Identities you can post *as* (personal / business).
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

    return options;
  }

  /// Communities the active profile may post *to*.
  static Future<List<PostDestinationOption>> fetchDestinations() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [PostDestinationOption.mainFeed()];
    }

    final destinations = <PostDestinationOption>[
      const PostDestinationOption.mainFeed(),
    ];

    try {
      final communities = await CommunityService.fetchMyCommunities(limit: 30);
      for (final community in communities) {
        if (!community.canPost) continue;
        destinations.add(
          PostDestinationOption(
            communityId: community.id,
            label: community.name,
            subtitle: community.locationLabel ?? 'Community',
          ),
        );
      }
    } catch (_) {}

    return destinations;
  }

  /// Legacy helper: identity options including communities (compat).
  static Future<List<PostIdentityOption>> fetchOptionsIncludingCommunities() async {
    final options = await fetchOptions();
    final destinations = await fetchDestinations();
    for (final destination in destinations) {
      if (destination.isMainFeed) continue;
      options.add(
        PostIdentityOption(
          kind: PostIdentityKind.community,
          communityId: destination.communityId,
          label: destination.label,
          subtitle: destination.subtitle ?? 'Community',
        ),
      );
    }
    return options;
  }
}
