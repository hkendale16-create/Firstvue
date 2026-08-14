import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_item.dart';
import '../services/community_hub_service.dart';
import '../services/community_news_service.dart';
import '../services/community_service.dart';
import '../services/profile_cards.dart';
import '../services/profile_media_service.dart';
import '../services/rentals_store.dart';
import '../services/things_to_do_service.dart';
import '../services/user_profile_service.dart';
import '../utils/explore_category_filter.dart';

/// Isolated Explore queries. Each section uses its own filter configuration.
class ExploreFeedService {
  ExploreFeedService._();

  static const pageSize = 24;

  static String? get _me => Supabase.instance.client.auth.currentUser?.id;

  static Future<ExplorePageResult> fetchPage({
    required ExploreSection section,
    DateTime? beforeCreatedAt,
    String? beforeId,
    int limit = pageSize,
  }) {
    return switch (section) {
      ExploreSection.people => _fetchPeople(
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        limit: limit,
      ),
      ExploreSection.communities => _fetchCommunities(
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        limit: limit,
      ),
      ExploreSection.groups => _fetchGroups(
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        limit: limit,
      ),
      ExploreSection.events => _fetchEvents(
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        limit: limit,
      ),
      ExploreSection.rentals => _fetchRentals(
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        limit: limit,
      ),
      ExploreSection.businesses ||
      ExploreSection.food ||
      ExploreSection.bars ||
      ExploreSection.thingsToDo => _fetchEntityPosts(
        section: section,
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        limit: limit,
      ),
    };
  }

  static dynamic _identityQuery(ExploreSection section, dynamic query) {
    return switch (section) {
      ExploreSection.people => query
          .isFilter('business_id', null)
          .isFilter('community_id', null),
      ExploreSection.events => query.or(
        'author_profile_type.eq.event,event_id.not.is.null',
      ),
      ExploreSection.groups => query.or(
        'author_profile_type.eq.community,community_id.not.is.null',
      ),
      ExploreSection.rentals ||
      ExploreSection.businesses ||
      ExploreSection.food ||
      ExploreSection.bars ||
      ExploreSection.thingsToDo => query.or(
        'author_profile_type.eq.business,author_profile_type.eq.professional,'
        'business_id.not.is.null,professional_profile_id.not.is.null',
      ),
      ExploreSection.communities => query,
    };
  }

  static Future<List<CommunityNewsPost>> _postsForSection({
    required ExploreSection section,
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    try {
      return await CommunityNewsService.fetchPosts(
        limit: limit,
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
        configure: (query) => _identityQuery(section, query),
      );
    } catch (_) {
      return CommunityNewsService.fetchPosts(
        limit: limit,
        beforeCreatedAt: beforeCreatedAt,
        beforeId: beforeId,
      );
    }
  }

  static Future<ExplorePageResult> _fetchPeople({
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    final items = <ExploreItem>[];
    if (beforeCreatedAt == null) {
      items.addAll(await _peopleRecommendations(limit: 8));
    }

    final posts = await _postsForSection(
      section: ExploreSection.people,
      beforeCreatedAt: beforeCreatedAt,
      beforeId: beforeId,
      limit: limit * 2,
    );
    for (final post in posts) {
      if (!ExploreCategoryFilter.matches(post, ExploreSection.people)) {
        continue;
      }
      items.add(
        ExploreItem.postItem(section: ExploreSection.people, post: post),
      );
    }
    return _page(items, limit: limit);
  }

  static Future<List<ExploreItem>> _peopleRecommendations({
    int limit = 8,
  }) async {
    try {
      final rows = await ProfileCards.listPublic(limit: limit * 2, excludeId: _me);
      final byId = <String, Map<String, dynamic>>{
        for (final row in rows)
          if (row['id'] is String) row['id'] as String: row,
      };
      final ids = byId.keys.take(limit).toList();
      if (ids.isEmpty) return const [];

      final avatars = await ProfileMediaService.fetchAvatarUrlsForProfiles(ids);
      final cards = <ExploreItem>[];
      for (final id in ids) {
        final row = byId[id];
        if (row == null) continue;
        if (row['is_private'] == true) continue;
        final visibility =
            (row['profile_visibility'] as String?) ?? 'public';
        if (visibility == 'private') continue;
        final profile = await UserProfileService.fetchProfileForUser(id);
        if (profile?.isPrivate == true) continue;
        final username = profile?.username ?? row['username'] as String?;
        cards.add(
          ExploreItem.profileItem(
            profile: ExploreProfileCard(
              id: id,
              displayName:
                  profile?.displayName ??
                  row['display_name'] as String? ??
                  'FirstVue member',
              handle: _handle(username),
              avatarUrl: avatars[id],
              locationLabel: profile?.locationLabel,
            ),
          ),
        );
      }
      return cards;
    } catch (_) {
      return const [];
    }
  }

  static String? _handle(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value.startsWith('@') ? value : '@$value';
  }

  static Future<ExplorePageResult> _fetchEntityPosts({
    required ExploreSection section,
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    final posts = await _postsForSection(
      section: section,
      beforeCreatedAt: beforeCreatedAt,
      beforeId: beforeId,
      limit: limit * 3,
    );
    final items = <ExploreItem>[];
    for (final post in posts) {
      if (post.media.isEmpty) continue;
      if (!ExploreCategoryFilter.matches(post, section)) continue;
      items.add(ExploreItem.postItem(section: section, post: post));
    }
    return _page(items, limit: limit);
  }

  static Future<ExplorePageResult> _fetchCommunities({
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    final items = <ExploreItem>[];
    if (beforeCreatedAt == null) {
      try {
        final hubs = await CommunityHubService.fetchNearbyHubs(limit: 12);
        for (final hub in hubs) {
          if (!hub.isDiscoverable) continue;
          items.add(
            ExploreItem.entityItem(
              section: ExploreSection.communities,
              entity: ExploreEntityCard(
                id: hub.id,
                kind: 'community',
                name: hub.name,
                handle: _handle(hub.handle),
                imageUrl: hub.imageUrl,
                subtitle: hub.locationLabel,
                createdAt: hub.createdAt,
              ),
            ),
          );
        }
      } catch (_) {}
    }

    try {
      final posts = await CommunityNewsService.fetchAllCommunitiesFeed(
        limit: limit * 2,
      );
      for (final post in posts) {
        if (beforeCreatedAt != null &&
            !post.createdAt.isBefore(beforeCreatedAt)) {
          continue;
        }
        if (beforeId != null && post.id == beforeId) continue;
        final input = post.exploreInput(
          communityShare: true,
          sourceLabel: post.communityName,
        );
        if (!input.viewerCanAccess) continue;
        items.add(
          ExploreItem.postItem(
            section: ExploreSection.communities,
            post: post,
            communityShare: true,
            originalSourceLabel: post.communityName,
          ),
        );
      }
    } catch (_) {}

    return _page(items, limit: limit);
  }

  static Future<ExplorePageResult> _fetchGroups({
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    final items = <ExploreItem>[];
    if (beforeCreatedAt == null) {
      try {
        final groups = await CommunityService.fetchNearbyCommunities(limit: 12);
        for (final group in groups) {
          items.add(
            ExploreItem.entityItem(
              section: ExploreSection.groups,
              entity: ExploreEntityCard(
                id: group.id,
                kind: 'group',
                name: group.name,
                imageUrl: group.imageUrl,
                subtitle: group.locationLabel,
                createdAt: group.createdAt,
              ),
            ),
          );
        }
      } catch (_) {}
    }

    final posts = await _postsForSection(
      section: ExploreSection.groups,
      beforeCreatedAt: beforeCreatedAt,
      beforeId: beforeId,
      limit: limit * 2,
    );
    for (final post in posts) {
      if (!ExploreCategoryFilter.matches(post, ExploreSection.groups)) continue;
      items.add(
        ExploreItem.postItem(section: ExploreSection.groups, post: post),
      );
    }
    return _page(items, limit: limit);
  }

  static Future<ExplorePageResult> _fetchEvents({
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    final items = <ExploreItem>[];
    if (beforeCreatedAt == null) {
      try {
        final events = await ThingsToDoService.fetchApprovedEvents();
        for (final event in events.take(12)) {
          items.add(
            ExploreItem.entityItem(
              section: ExploreSection.events,
              entity: ExploreEntityCard(
                id: event.id,
                kind: 'event',
                name: event.title,
                imageUrl: event.coverImageUrl,
                subtitle: event.locationLabel ?? event.businessName,
                createdAt: event.createdAt ?? event.eventAt,
              ),
            ),
          );
        }
      } catch (_) {}
    }

    final posts = await _postsForSection(
      section: ExploreSection.events,
      beforeCreatedAt: beforeCreatedAt,
      beforeId: beforeId,
      limit: limit * 2,
    );
    for (final post in posts) {
      if (post.media.isEmpty) continue;
      if (!ExploreCategoryFilter.matches(post, ExploreSection.events)) continue;
      items.add(
        ExploreItem.postItem(section: ExploreSection.events, post: post),
      );
    }
    return _page(items, limit: limit);
  }

  static Future<ExplorePageResult> _fetchRentals({
    DateTime? beforeCreatedAt,
    String? beforeId,
    required int limit,
  }) async {
    final items = <ExploreItem>[];
    if (beforeCreatedAt == null) {
      try {
        final listings = await RentalsStore.fetchApprovedListings(limit: 12);
        for (final listing in listings) {
          items.add(
            ExploreItem.entityItem(
              section: ExploreSection.rentals,
              entity: ExploreEntityCard(
                id: listing.id,
                kind: 'rental',
                name: listing.title,
                imageUrl: listing.media.isEmpty
                    ? null
                    : listing.media.first.signedUrl,
                subtitle: listing.monthlyPrice ?? listing.weeklyPrice,
              ),
            ),
          );
        }
      } catch (_) {}
    }

    final entityPage = await _fetchEntityPosts(
      section: ExploreSection.rentals,
      beforeCreatedAt: beforeCreatedAt,
      beforeId: beforeId,
      limit: limit,
    );
    items.addAll(entityPage.items);
    return _page(items, limit: limit);
  }

  static ExplorePageResult _page(
    List<ExploreItem> items, {
    required int limit,
  }) {
    final seen = <String>{};
    final deduped = <ExploreItem>[];
    for (final item in items) {
      if (seen.add(item.id)) deduped.add(item);
    }
    final page = deduped.take(limit).toList(growable: false);
    DateTime? cursorCreatedAt;
    String? cursorId;
    for (var i = page.length - 1; i >= 0; i--) {
      final item = page[i];
      if (item.post != null) {
        cursorCreatedAt = item.post!.createdAt;
        cursorId = item.post!.id;
        break;
      }
    }
    return ExplorePageResult(
      items: page,
      hasMore: deduped.length >= limit,
      cursorCreatedAt: cursorCreatedAt,
      cursorId: cursorId,
    );
  }
}
