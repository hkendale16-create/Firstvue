import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/community_hub_detail_screen.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/professional_public_profile_screen.dart';
import '../services/community_news_service.dart';
import '../services/professional_profiles_service.dart';
import '../services/shoutout_service.dart';
import '../services/things_to_do_service.dart';
import '../widgets/event_profile_sheet.dart';

class EntityNavigation {
  EntityNavigation._();

  static Future<void> openShoutoutTarget(
    BuildContext context, {
    required ShoutoutTargetType type,
    required String id,
  }) async {
    if (id.trim().isEmpty) return;

    switch (type) {
      case ShoutoutTargetType.profile:
        openMemberProfile(context, profileId: id);
        return;
      case ShoutoutTargetType.business:
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => FirstVueBusinessProfileScreen(businessId: id),
          ),
        );
        return;
      case ShoutoutTargetType.professional:
        await _openProfessional(context, id);
        return;
      case ShoutoutTargetType.event:
        await openEvent(context, id);
        return;
      case ShoutoutTargetType.group:
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityDetailScreen(communityId: id),
          ),
        );
        return;
      case ShoutoutTargetType.community:
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityHubDetailScreen(hubId: id),
          ),
        );
        return;
    }
  }

  static Future<void> openCommunitiesBrowse(
    BuildContext context, {
    bool allowCreate = false,
  }) {
    return Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CommunitiesScreen(allowCreate: allowCreate),
      ),
    );
  }

  static Future<void> _openProfessional(BuildContext context, String id) async {
    try {
      final row = await ProfessionalProfilesService.fetchById(id);
      if (!context.mounted || row == null) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => ProfessionalPublicProfileScreen(
            profile: row,
            icon: Icons.badge_outlined,
          ),
        ),
      );
    } catch (_) {}
  }

  static Future<void> openEvent(BuildContext context, String id) async {
    if (id.trim().isEmpty) return;
    try {
      final events = await ThingsToDoService.fetchApprovedEvents();
      if (!context.mounted) return;
      CommunityEvent? match;
      for (final event in events) {
        if (event.id == id) {
          match = event;
          break;
        }
      }
      if (match == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That event is no longer available.')),
        );
        return;
      }
      await EventProfileSheet.show(context, event: match);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this event.')),
      );
    }
  }

  static Future<void> openPostAuthor(
    BuildContext context, {
    required CommunityNewsPost post,
  }) async {
    final type = post.resolvedAuthorProfileType;
    final id = post.entityNavigationId;
    if (id == null || id.trim().isEmpty) {
      openMemberProfile(context, profileId: post.authorId);
      return;
    }

    switch (type) {
      case 'business':
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => FirstVueBusinessProfileScreen(businessId: id),
          ),
        );
        return;
      case 'professional':
        await _openProfessional(context, id);
        return;
      case 'event':
        await openEvent(context, id);
        return;
      case 'community':
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityHubDetailScreen(hubId: id),
          ),
        );
        return;
      case 'group':
        await Navigator.push(
          context,
          FirstVuePageRoute(
            builder: (_) => CommunityDetailScreen(communityId: id),
          ),
        );
        return;
      default:
        openMemberProfile(context, profileId: post.authorId);
    }
  }
}
