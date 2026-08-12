import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/community_detail_screen.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/professional_public_profile_screen.dart';
import '../services/professional_profiles_service.dart';
import '../services/search_autocomplete_service.dart';
import '../services/shoutout_service.dart';
import '../services/things_to_do_service.dart';
import '../widgets/event_profile_sheet.dart';

/// Opens the correct destination for a shoutout / search entity by stable ID.
class EntityNavigation {
  EntityNavigation._();

  static Future<void> openSearchResult(
    BuildContext context,
    SearchAutocompleteResult result,
  ) {
    return openTyped(
      context,
      type: switch (result.type) {
        SearchResultType.profile => ShoutoutTargetType.profile,
        SearchResultType.business => ShoutoutTargetType.business,
        SearchResultType.professional => ShoutoutTargetType.professional,
        SearchResultType.event => ShoutoutTargetType.event,
        SearchResultType.community => ShoutoutTargetType.community,
        SearchResultType.hashtag => null,
      },
      id: result.id,
    );
  }

  static Future<void> openShoutoutTarget(
    BuildContext context, {
    required ShoutoutTargetType type,
    required String id,
  }) {
    return openTyped(context, type: type, id: id);
  }

  static Future<void> openTyped(
    BuildContext context, {
    required ShoutoutTargetType? type,
    required String id,
  }) async {
    if (type == null || id.trim().isEmpty) return;

    switch (type) {
      case ShoutoutTargetType.profile:
        openMemberProfile(context, profileId: id);
      case ShoutoutTargetType.business:
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => FirstVueBusinessProfileScreen(businessId: id),
          ),
        );
      case ShoutoutTargetType.professional:
        final profile = await ProfessionalProfilesService.fetchById(id);
        if (!context.mounted) return;
        if (profile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Professional profile unavailable.')),
          );
          return;
        }
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => ProfessionalPublicProfileScreen(
              profile: profile,
              icon: Icons.badge_outlined,
            ),
          ),
        );
      case ShoutoutTargetType.event:
        final event = await ThingsToDoService.fetchEventById(id);
        if (!context.mounted) return;
        if (event == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event unavailable.')),
          );
          return;
        }
        await EventProfileSheet.show(context, event: event);
      case ShoutoutTargetType.community:
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityDetailScreen(communityId: id),
          ),
        );
    }
  }
}
