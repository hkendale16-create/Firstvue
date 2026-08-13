import 'dart:ui' show Color;

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';
import 'community_news_media_service.dart';
import 'community_service.dart';
import 'follow_service.dart';
import 'post_metadata_service.dart';
import 'saved_items_service.dart';
import '../models/publish_destination.dart';

class ProfileEngagementStats {
  final int postCount;
  final int sparksReceived;

  const ProfileEngagementStats({
    required this.postCount,
    required this.sparksReceived,
  });
}

class CommunityNewsPost {
  final String id;
  final String body;
  final String authorId;
  final String authorName;
  final String? authorUsername;
  final String? authorProfileType;
  final String? businessId;
  final String? businessName;
  final String? businessType;
  final String? professionalProfileId;
  final String? eventId;
  final String? communityId;
  final String? communityName;
  final String? communityImageUrl;
  final DateTime createdAt;
  final bool isMine;
  final int sparkCount;
  final bool sparkedByMe;
  final bool savedByMe;
  final int repostCount;
  final String visibility;
  final String? backgroundColor;
  final PublishDestination publishDestination;
  final List<CommunityNewsMediaItem> media;

  const CommunityNewsPost({
    required this.id,
    required this.body,
    required this.authorId,
    required this.authorName,
    this.authorUsername,
    this.authorProfileType,
    this.businessId,
    required this.businessName,
    this.businessType,
    this.professionalProfileId,
    this.eventId,
    this.communityId,
    this.communityName,
    this.communityImageUrl,
    required this.createdAt,
    required this.isMine,
    required this.sparkCount,
    required this.sparkedByMe,
    required this.savedByMe,
    this.repostCount = 0,
    this.visibility = 'public',
    this.backgroundColor,
    this.publishDestination = PublishDestination.feed,
    this.media = const [],
  });

  String get commentsMediaId => 'news-post:$id';

  /// Subtle panel fill for composer / post body backgrounds.
  static Color? backgroundFill(String? key) {
    return switch (key) {
      null || 'none' || '' => null,
      'bronze' => const Color(0x33E5C16F),
      'teal' => const Color(0x333DD9C9),
      'coral' => const Color(0x33FF7A59),
      'navy' => const Color(0x44243B6B),
      'forest' => const Color(0x331F6B4A),
      'sunset' => const Color(0x33D9894B),
      'midnight' => const Color(0x4412162A),
      _ => null,
    };
  }

  CommunityNewsPost copyWith({
    String? id,
    String? body,
    String? authorId,
    String? authorName,
    String? authorUsername,
    String? authorProfileType,
    String? businessId,
    String? businessName,
    String? businessType,
    String? professionalProfileId,
    String? eventId,
    String? communityId,
    String? communityName,
    String? communityImageUrl,
    DateTime? createdAt,
    bool? isMine,
    int? sparkCount,
    bool? sparkedByMe,
    bool? savedByMe,
    int? repostCount,
    String? visibility,
    String? backgroundColor,
    PublishDestination? publishDestination,
    List<CommunityNewsMediaItem>? media,
  }) {
    return CommunityNewsPost(
      id: id ?? this.id,
      body: body ?? this.body,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorUsername: authorUsername ?? this.authorUsername,
      authorProfileType: authorProfileType ?? this.authorProfileType,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      professionalProfileId:
          professionalProfileId ?? this.professionalProfileId,
      eventId: eventId ?? this.eventId,
      communityId: communityId ?? this.communityId,
      communityName: communityName ?? this.communityName,
      communityImageUrl: communityImageUrl ?? this.communityImageUrl,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      sparkCount: sparkCount ?? this.sparkCount,
      sparkedByMe: sparkedByMe ?? this.sparkedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
      repostCount: repostCount ?? this.repostCount,
      visibility: visibility ?? this.visibility,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      publishDestination: publishDestination ?? this.publishDestination,
      media: media ?? this.media,
    );
  }
}

class CommunityNewsService {
  CommunityNewsService._();

  static final _client = Supabase.instance.client;

  static const _postColumnsWithBackground =
      'id, body, created_at, author_id, business_id, community_id, visibility, professional_profile_id, event_id, author_profile_type, author_profile_id, background_color, publish_destination';

  static const _postColumns =
      'id, body, created_at, author_id, business_id, community_id, visibility, professional_profile_id, event_id, author_profile_type, author_profile_id';

  static const _postColumnsBase =
      'id, body, created_at, author_id, business_id, community_id';

  /// Builds a select query with filters applied *after* `.select()`.
  ///
  /// Calling `.order` / `.eq` / `.limit` on the pre-select builder (and
  /// discarding the returned filter builder) breaks feed loading.
  static Future<List<dynamic>> _selectPosts(
    dynamic Function(dynamic query) configure,
  ) async {
    Future<List<dynamic>> run(String columns) async {
      dynamic query = _client.from('community_news_posts').select(columns);
      query = configure(query);
      final rows = await query;
      if (rows is List) return rows;
      return const [];
    }

    try {
      return await run(_postColumnsWithBackground);
    } catch (_) {
      try {
        return await run(_postColumns);
      } catch (_) {
        try {
          return await run(
            'id, body, created_at, author_id, business_id, community_id, visibility',
          );
        } catch (_) {
          return await run(_postColumnsBase);
        }
      }
    }
  }

  static void logFeedError(Object error, {String context = 'NewsFeed'}) {
    if (error is PostgrestException) {
      // ignore: avoid_print
      print(
        '[$context] PostgrestException '
        'code=${error.code} message=${error.message} '
        'details=${error.details} hint=${error.hint}',
      );
      return;
    }
    // ignore: avoid_print
    print('[$context] $error');
  }

  static Future<Map<String, dynamic>> _insertPostReturning(
    Map<String, dynamic> insertPayload,
  ) async {
    Future<Map<String, dynamic>> attempt(
      Map<String, dynamic> payload,
      String columns,
    ) {
      return _client
          .from('community_news_posts')
          .insert(payload)
          .select(columns)
          .single();
    }

    try {
      return await attempt(insertPayload, _postColumnsWithBackground);
    } catch (_) {
      final withoutBg = Map<String, dynamic>.from(insertPayload)
        ..remove('background_color')
        ..remove('publish_destination');
      try {
        return await attempt(withoutBg, _postColumns);
      } catch (_) {
        final fallback = Map<String, dynamic>.from(withoutBg)
          ..remove('author_profile_type')
          ..remove('author_profile_id')
          ..remove('visibility');
        try {
          return await attempt(
            Map<String, dynamic>.from(withoutBg)
              ..remove('author_profile_type')
              ..remove('author_profile_id'),
            'id, body, created_at, author_id, business_id, community_id, '
            'visibility, professional_profile_id, event_id',
          );
        } catch (_) {
          return await attempt(fallback, _postColumnsBase);
        }
      }
    }
  }

  static final _misleadingTeaserPattern = RegExp(
    r'^follow(\s+(this\s+(account|profile|member|user)))?\s+(for|to(\s+see)?)\s+(more(\s+details)?|the(\s+full(\s+post)?)?)\.?$',
    caseSensitive: false,
  );

  static bool isMisleadingFollowTeaser(String body) {
    return _misleadingTeaserPattern.hasMatch(body.trim());
  }

  static String resolveDisplayBody({
    required String rawBody,
    required String visibility,
    required bool isMine,
    required bool followsAuthor,
    required bool hasMedia,
  }) {
    final trimmed = rawBody.trim();
    if (trimmed.isEmpty) return trimmed;

    final teaser = isMisleadingFollowTeaser(trimmed);
    final canViewFull =
        isMine ||
        visibility == 'public' ||
        (visibility == 'followers' && followsAuthor);

    if (teaser && !canViewFull && visibility == 'followers') {
      return 'Follow this member to see the full post.';
    }

    if (teaser && canViewFull && hasMedia) {
      return '';
    }

    return trimmed;
  }

  static Future<List<CommunityNewsPost>> fetchPosts({
    int limit = 20,
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) async {
    final me = _client.auth.currentUser?.id;
    // RLS returns approved posts plus the signed-in author's own posts.
    final rows = await _selectPosts((query) {
      var q = query.order('created_at', ascending: false).limit(limit);
      if (beforeCreatedAt != null) {
        q = q.lt('created_at', beforeCreatedAt.toUtc().toIso8601String());
      }
      return q;
    });

    final mapped = await _mapPostRows(rows, currentUserId: me);
    // beforeId soft-ties when many posts share the same created_at.
    if (beforeId == null || beforeId.isEmpty) {
      return _dedupePosts(mapped);
    }
    return _dedupePosts(
      mapped.where((post) => post.id != beforeId).toList(growable: false),
    );
  }

  /// Explore grid posts (media-first) with cursor pagination.
  static Future<List<CommunityNewsPost>> fetchExplorePosts({
    int limit = 24,
    DateTime? beforeCreatedAt,
    String? beforeId,
    String? profileType,
    String? businessType,
  }) async {
    // Over-fetch slightly so client filters still fill a page.
    final fetchLimit = (profileType != null || businessType != null)
        ? limit * 3
        : limit;
    final posts = await fetchPosts(
      limit: fetchLimit,
      beforeCreatedAt: beforeCreatedAt,
      beforeId: beforeId,
    );
    final withMedia = posts.where((post) => post.media.isNotEmpty);
    final filtered = withMedia.where((post) {
      if (profileType != null && profileType.isNotEmpty) {
        final type = (post.authorProfileType ?? _inferProfileType(post))
            .toLowerCase();
        if (type != profileType.toLowerCase()) return false;
      }
      if (businessType != null && businessType.isNotEmpty) {
        final bt = (post.businessType ?? '').toLowerCase();
        final services = bt;
        final needle = businessType.toLowerCase();
        if (!bt.contains(needle) && !services.contains(needle)) {
          // Also match common aliases from post context name.
          final name = (post.businessName ?? '').toLowerCase();
          if (!name.contains(needle)) return false;
        }
      }
      return true;
    });
    return filtered.take(limit).toList(growable: false);
  }

  static String _inferProfileType(CommunityNewsPost post) {
    if (post.businessId != null) return 'business';
    if (post.professionalProfileId != null) return 'professional';
    if (post.eventId != null) return 'event';
    if (post.communityId != null) return 'community';
    return 'user';
  }

  /// Ranked Home/main Newsfeed (recency + unseen + relevance + controlled variance).
  static Future<List<CommunityNewsPost>> fetchRankedMainFeed({
    int limit = 30,
    double? seed,
  }) async {
    final me = _client.auth.currentUser?.id;

    try {
      final result = await _client.rpc(
        'fetch_ranked_main_feed',
        params: {'p_limit': limit, 'p_seed': seed},
      );
      if (result is! List || result.isEmpty) {
        return me == null ? await fetchPosts(limit: limit) : const [];
      }
      final mapped = await _mapPostRows(result, currentUserId: me);
      return mapped
          .where((post) => post.publishDestination.appearsOnHome)
          .toList(growable: false);
    } catch (_) {
      final posts = await fetchPosts(limit: limit);
      return posts
          .where((post) => post.publishDestination.appearsOnHome)
          .toList(growable: false);
    }
  }

  /// Chronological New feed (`created_at DESC`) with cursor pagination.
  static Future<List<CommunityNewsPost>> fetchNewFeed({
    int limit = 20,
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) async {
    final me = _client.auth.currentUser?.id;
    try {
      final result = await _client.rpc(
        'fetch_new_feed',
        params: {
          'p_limit': limit,
          'p_before': beforeCreatedAt?.toUtc().toIso8601String(),
          'p_before_id': beforeId,
        },
      );
      if (result is List && result.isNotEmpty) {
        return _dedupePosts(await _mapPostRows(result, currentUserId: me));
      }
    } catch (error) {
      logFeedError(error, context: 'fetchNewFeed');
    }

    final rows = await _selectPosts((query) {
      var q = query.order('created_at', ascending: false).limit(limit);
      if (beforeCreatedAt != null) {
        q = q.lt('created_at', beforeCreatedAt.toUtc().toIso8601String());
      }
      return q;
    });
    return _dedupePosts(await _mapPostRows(rows, currentUserId: me));
  }

  /// Trending feed ranked by recent engagement momentum (~48h window).
  static Future<List<CommunityNewsPost>> fetchTrendingFeed({
    int limit = 20,
    int windowHours = 48,
  }) async {
    final me = _client.auth.currentUser?.id;
    try {
      final result = await _client.rpc(
        'fetch_trending_feed',
        params: {'p_limit': limit, 'p_window_hours': windowHours},
      );
      if (result is List && result.isNotEmpty) {
        return _dedupePosts(await _mapPostRows(result, currentUserId: me));
      }
    } catch (error) {
      logFeedError(error, context: 'fetchTrendingFeed');
    }
    // Fallback: recent posts ordered by spark count heuristic client-side.
    final posts = await fetchPosts(limit: limit * 2);
    final sorted = [...posts]
      ..sort((a, b) {
        final scoreA = a.sparkCount * 1.0 + a.repostCount * 4.0;
        final scoreB = b.sparkCount * 1.0 + b.repostCount * 4.0;
        final cmp = scoreB.compareTo(scoreA);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
    return _dedupePosts(sorted.take(limit).toList());
  }

  /// Rule-based Recommended feed with cold-start fallback.
  static Future<List<CommunityNewsPost>> fetchRecommendedFeed({
    int limit = 20,
    double? seed,
  }) async {
    final me = _client.auth.currentUser?.id;
    try {
      final result = await _client.rpc(
        'fetch_recommended_feed',
        params: {
          'p_limit': limit,
          'p_seed': seed ?? DateTime.now().millisecondsSinceEpoch.toDouble(),
        },
      );
      if (result is List && result.isNotEmpty) {
        return _dedupePosts(await _mapPostRows(result, currentUserId: me));
      }
    } catch (error) {
      logFeedError(error, context: 'fetchRecommendedFeed');
    }
    return _dedupePosts(await fetchRankedMainFeed(limit: limit, seed: seed));
  }

  /// Aggregated Communities (hub) feed for all hubs the user can access.
  static Future<List<CommunityNewsPost>> fetchAllCommunitiesFeed({
    int limit = 20,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];
    try {
      final hubs = await _client
          .from('community_hubs')
          .select('id')
          .eq('status', 'active')
          .limit(40);
      final hubIds = hubs
          .map((r) => r['id'] as String?)
          .whereType<String>()
          .toList();
      if (hubIds.isEmpty) return const [];

      final all = <CommunityNewsPost>[];
      for (final hubId in hubIds.take(12)) {
        final page = await fetchHubCommunityFeed(hubId, limit: 8);
        all.addAll(page);
      }
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _dedupePosts(all.take(limit).toList());
    } catch (error) {
      logFeedError(error, context: 'fetchAllCommunitiesFeed');
      return const [];
    }
  }

  static List<CommunityNewsPost> _dedupePosts(List<CommunityNewsPost> posts) {
    final seen = <String>{};
    final out = <CommunityNewsPost>[];
    for (final post in posts) {
      if (seen.add(post.id)) out.add(post);
    }
    return out;
  }

  /// Umbrella Community feed: Group posts referenced by `community_feed_posts`.
  ///
  /// Mapped posts keep the source Group's name/image on
  /// [CommunityNewsPost.communityName] / [communityImageUrl] so UI can show
  /// "[User] in [Group]".
  static Future<List<CommunityNewsPost>> fetchHubCommunityFeed(
    String hubId, {
    int limit = 30,
  }) async {
    if (hubId.trim().isEmpty) return const [];
    final me = _client.auth.currentUser?.id;

    try {
      final feedRows = await _client
          .from('community_feed_posts')
          .select('id, community_id, group_id, source_post_id, created_at')
          .eq('community_id', hubId)
          .isFilter('removed_from_community_at', null)
          .order('created_at', ascending: false)
          .limit(limit);

      if (feedRows.isEmpty) return const [];

      final sourceIds = <String>[];
      final groupBySource = <String, String>{};
      for (final row in feedRows) {
        final sourceId = row['source_post_id'] as String?;
        final groupId = row['group_id'] as String?;
        if (sourceId == null) continue;
        sourceIds.add(sourceId);
        if (groupId != null) groupBySource[sourceId] = groupId;
      }
      if (sourceIds.isEmpty) return const [];

      final postRows = await _selectPosts(
        (query) => query.inFilter('id', sourceIds),
      );
      if (postRows.isEmpty) return const [];

      // Preserve community_feed_posts ordering.
      final byId = <String, Map<String, dynamic>>{
        for (final row in postRows)
          if (row['id'] is String)
            row['id'] as String: Map<String, dynamic>.from(row as Map),
      };
      final ordered = <Map<String, dynamic>>[];
      for (final id in sourceIds) {
        final row = byId[id];
        if (row == null) continue;
        // Ensure group context is present for mapping "[User] in [Group]".
        final groupId = groupBySource[id];
        if (groupId != null && row['community_id'] == null) {
          row['community_id'] = groupId;
        }
        ordered.add(row);
      }

      return await _mapPostRows(ordered, currentUserId: me);
    } catch (_) {
      return const [];
    }
  }

  /// Personal posts only (excludes Business / Professional entity posts).
  static Future<List<CommunityNewsPost>> fetchMyPosts({
    int limit = 10,
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final rows = await _selectPosts((query) {
        var q = query
            .eq('author_id', me.id)
            .filter('business_id', 'is', null)
            .filter('professional_profile_id', 'is', null)
            .order('created_at', ascending: false)
            .limit(limit);
        if (beforeCreatedAt != null) {
          q = q.lt('created_at', beforeCreatedAt.toUtc().toIso8601String());
        }
        return q;
      });

      final mapped = await _mapPostRows(rows, currentUserId: me.id);
      if (beforeId == null || beforeId.isEmpty) return mapped;
      return mapped.where((post) => post.id != beforeId).toList();
    } catch (_) {
      try {
        final rows = await _selectPosts((query) {
          var q = query
              .eq('author_id', me.id)
              .order('created_at', ascending: false)
              .limit(limit);
          if (beforeCreatedAt != null) {
            q = q.lt('created_at', beforeCreatedAt.toUtc().toIso8601String());
          }
          return q;
        });
        final mapped = await _mapPostRows(rows, currentUserId: me.id);
        return mapped
            .where(
              (p) =>
                  p.businessName == null ||
                  (p.communityId != null && p.businessName == p.communityName),
            )
            .where((p) => beforeId == null || p.id != beforeId)
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<List<CommunityNewsPost>> _mapPostRows(
    List<dynamic> rows, {
    required String? currentUserId,
  }) async {
    if (rows.isEmpty) return const [];

    final postIds = rows.map((row) => row['id'] as String).toList();
    final authorIds = rows
        .map((row) => row['author_id'] as String)
        .toSet()
        .toList();
    final businessIds = rows
        .map((row) => row['business_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final communityIds = rows
        .map((row) => row['community_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final professionalIds = rows
        .map((row) => row['professional_profile_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    final eventIds = rows
        .map((row) => row['event_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final authorNames = await _fetchProfileNames(authorIds);
    final authorUsernames = await _fetchProfileUsernames(authorIds);
    final businessInfo = await _fetchBusinessInfo(businessIds);
    final communityNames = await _fetchCommunityNames(communityIds);
    final communityImages = await _fetchCommunityImages(communityIds);
    final professionalNames = await _fetchProfessionalNames(professionalIds);
    final eventTitles = await _fetchEventTitles(eventIds);
    final sparkCounts = await _fetchSparkCounts(postIds);
    final mySparks = currentUserId == null
        ? const <String>{}
        : await _fetchMySparks(postIds, currentUserId);
    final mySaves = currentUserId == null
        ? const <String>{}
        : await SavedItemsService.fetchSavedIds(
            contentType: SavedContentType.newsPost,
            contentIds: postIds,
          );
    final mediaByPost = await CommunityNewsMediaService.fetchMediaByPostIds(
      postIds,
    );
    final followingAuthors = await _followingAuthorIds(
      authorIds,
      currentUserId: currentUserId,
    );

    final posts = <CommunityNewsPost>[];
    for (final row in rows) {
      try {
        final id = row['id'] as String?;
        final authorId = row['author_id'] as String?;
        if (id == null || authorId == null) continue;

        final businessId = row['business_id'] as String?;
        final communityId = row['community_id'] as String?;
        final professionalProfileId = row['professional_profile_id'] as String?;
        final eventId = row['event_id'] as String?;
        final visibility = (row['visibility'] as String?) ?? 'public';
        final createdRaw = row['created_at'];
        final createdAt = createdRaw is String
            ? DateTime.tryParse(createdRaw) ?? DateTime.now()
            : createdRaw is DateTime
            ? createdRaw
            : DateTime.now();
        final contextName = businessId != null
            ? businessInfo[businessId]?.name
            : professionalProfileId != null
            ? professionalNames[professionalProfileId]
            : eventId != null
            ? eventTitles[eventId]
            : (communityId != null ? communityNames[communityId] : null);
        final media = mediaByPost[id] ?? const [];
        final isMine = authorId == currentUserId;
        final followsAuthor = followingAuthors.contains(authorId);
        final rawBody = (row['body'] as String?) ?? '';
        final body = resolveDisplayBody(
          rawBody: rawBody,
          visibility: visibility,
          isMine: isMine,
          followsAuthor: followsAuthor,
          hasMedia: media.isNotEmpty,
        );
        String? backgroundColor;
        try {
          final rawBg = row['background_color'] as String?;
          if (rawBg != null && rawBg.trim().isNotEmpty && rawBg != 'none') {
            backgroundColor = rawBg.trim();
          }
        } catch (_) {}
        PublishDestination publishDestination = PublishDestination.feed;
        try {
          publishDestination = PublishDestination.parse(
            row['publish_destination'] as String?,
          );
        } catch (_) {}
        final authorProfileType = row['author_profile_type'] as String?;

        posts.add(
          CommunityNewsPost(
            id: id,
            body: body,
            authorId: authorId,
            authorName: authorNames[authorId] ?? 'FirstVue member',
            authorUsername: authorUsernames[authorId],
            authorProfileType: authorProfileType,
            businessId: businessId,
            businessName: contextName,
            businessType: businessId == null
                ? null
                : businessInfo[businessId]?.type,
            professionalProfileId: professionalProfileId,
            eventId: eventId,
            communityId: communityId,
            communityName: communityId == null
                ? null
                : communityNames[communityId],
            communityImageUrl: communityId == null
                ? null
                : communityImages[communityId],
            createdAt: createdAt,
            isMine: isMine,
            sparkCount: sparkCounts[id] ?? 0,
            sparkedByMe: mySparks.contains(id),
            savedByMe: mySaves.contains(id),
            visibility: visibility,
            backgroundColor: backgroundColor,
            publishDestination: publishDestination,
            media: media,
          ),
        );
      } catch (error) {
        assert(() {
          // ignore: avoid_print
          print('Skipping malformed news post row: $error');
          return true;
        }());
      }
    }
    return posts;
  }

  static Future<Map<String, String>> _fetchCommunityImages(
    List<String> communityIds,
  ) async {
    if (communityIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('communities')
          .select('id, image_url')
          .inFilter('id', communityIds);
      return {
        for (final row in rows)
          if (row['image_url'] is String &&
              (row['image_url'] as String).trim().isNotEmpty)
            row['id'] as String: row['image_url'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  static Future<Set<String>> _followingAuthorIds(
    List<String> authorIds, {
    required String? currentUserId,
  }) async {
    if (currentUserId == null || authorIds.isEmpty) return const {};
    try {
      return await FollowService.fetchFollowingIdsAmong(authorIds);
    } catch (_) {
      return const {};
    }
  }

  static String normalizePostId(String raw) {
    final trimmed = raw.trim();
    const prefix = 'news-post:';
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }
    return trimmed;
  }

  static Future<List<CommunityNewsPost>> mapPostRowsPublic(List<dynamic> rows) {
    return _mapPostRows(rows, currentUserId: _client.auth.currentUser?.id);
  }

  static Future<Map<String, String>> _fetchProfileNames(
    List<String> authorIds,
  ) async {
    if (authorIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, display_name')
          .inFilter('id', authorIds);
      return {
        for (final row in rows)
          row['id'] as String:
              (row['display_name'] as String?) ?? 'FirstVue member',
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _fetchProfileUsernames(
    List<String> authorIds,
  ) async {
    if (authorIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id, username')
          .inFilter('id', authorIds);
      return {
        for (final row in rows)
          if ((row['username'] as String?)?.trim().isNotEmpty == true)
            row['id'] as String: (row['username'] as String).trim(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _fetchBusinessNames(
    List<String> businessIds,
  ) async {
    final info = await _fetchBusinessInfo(businessIds);
    return {for (final entry in info.entries) entry.key: entry.value.name};
  }

  static Future<Map<String, ({String name, String? type})>> _fetchBusinessInfo(
    List<String> businessIds,
  ) async {
    if (businessIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('businesses')
          .select('id, name, business_type')
          .inFilter('id', businessIds);
      return {
        for (final row in rows)
          row['id'] as String: (
            name: row['name'] as String? ?? 'Business',
            type: row['business_type'] as String?,
          ),
      };
    } catch (_) {
      try {
        final rows = await _client
            .from('businesses')
            .select('id, name')
            .inFilter('id', businessIds);
        return {
          for (final row in rows)
            row['id'] as String: (
              name: row['name'] as String? ?? 'Business',
              type: null,
            ),
        };
      } catch (_) {
        return {};
      }
    }
  }

  static Future<Map<String, String>> _fetchCommunityNames(
    List<String> communityIds,
  ) async {
    if (communityIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('communities')
          .select('id, name')
          .inFilter('id', communityIds);
      return {
        for (final row in rows) row['id'] as String: row['name'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _fetchProfessionalNames(
    List<String> professionalProfileIds,
  ) async {
    if (professionalProfileIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('professional_profiles')
          .select('id, display_name')
          .inFilter('id', professionalProfileIds);
      return {
        for (final row in rows)
          row['id'] as String: row['display_name'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _fetchEventTitles(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('community_events')
          .select('id, title')
          .inFilter('id', eventIds);
      return {
        for (final row in rows) row['id'] as String: row['title'] as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _assertCanPostAs({
    required String userId,
    String? businessId,
    String? professionalProfileId,
    String? eventId,
  }) async {
    if (businessId != null) {
      final owned = await _client
          .from('businesses')
          .select('id')
          .eq('id', businessId)
          .eq('created_by', userId)
          .maybeSingle();
      if (owned == null) {
        throw const AuthException(
          'You can only post for businesses you manage.',
        );
      }
    }

    if (professionalProfileId != null) {
      final owned = await _client
          .from('professional_profiles')
          .select('id')
          .eq('id', professionalProfileId)
          .eq('profile_id', userId)
          .maybeSingle();
      if (owned == null) {
        throw const AuthException(
          'You can only post for your professional profile.',
        );
      }
    }

    if (eventId != null) {
      final owned = await _client
          .from('community_events')
          .select('id')
          .eq('id', eventId)
          .eq('organizer_id', userId)
          .maybeSingle();
      if (owned == null) {
        throw const AuthException('You can only post for events you organize.');
      }
    }
  }

  static Future<void> _ensureProfile(User user) async {
    final displayName = user.email?.split('@').first;
    try {
      await _client.rpc(
        'ensure_user_profile',
        params: {'display_name': displayName},
      );
    } catch (_) {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      if (existing == null) {
        await _client.from('profiles').insert({
          'id': user.id,
          'display_name': displayName,
        });
      }
    }
  }

  static Future<Map<String, int>> _fetchSparkCounts(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('community_news_post_sparks')
          .select('post_id')
          .inFilter('post_id', postIds);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['post_id'] as String;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> _fetchMySparks(
    List<String> postIds,
    String userId,
  ) async {
    if (postIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('community_news_post_sparks')
          .select('post_id')
          .eq('user_id', userId)
          .inFilter('post_id', postIds);
      return rows.map((row) => row['post_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Single post by id (author's own or approved), for detail sheets.
  static Future<CommunityNewsPost?> fetchPostById(String id) async {
    final postId = normalizePostId(id);
    if (postId.isEmpty) return null;

    final me = _client.auth.currentUser?.id;

    try {
      final rows = await _selectPosts(
        (query) => query.eq('id', postId).limit(1),
      );

      if (rows.isNotEmpty) {
        final posts = await _mapPostRows(rows, currentUserId: me);
        if (posts.isNotEmpty) return posts.first;
      }
    } catch (_) {
      // Fall through to author fallback below.
    }

    if (me != null) {
      try {
        final mine = await fetchMyPosts(limit: 50);
        for (final post in mine) {
          if (post.id == postId) return post;
        }
      } catch (_) {}
    }

    return null;
  }

  static Future<CommunityNewsPost> createPost(
    String body, {
    String? businessId,
    String? communityId,
    String? professionalProfileId,
    String? eventId,
    List<XFile> files = const [],
    String? backgroundColor,
    String? visibility,
    PublishDestination publishDestination = PublishDestination.feed,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to post.');
    final trimmed = body.trim();
    if (trimmed.isEmpty && files.isEmpty) {
      throw ArgumentError('Add text or attach a photo/video.');
    }

    await _ensureProfile(me);
    await _assertCanPostAs(
      userId: me.id,
      businessId: businessId,
      professionalProfileId: professionalProfileId,
      eventId: eventId,
    );

    final insertPayload = <String, dynamic>{
      'author_id': me.id,
      'body': trimmed,
      'status': 'approved',
      'author_profile_type': 'user',
    };
    if (businessId != null) {
      insertPayload['business_id'] = businessId;
      insertPayload['author_profile_type'] = 'business';
      insertPayload['author_profile_id'] = businessId;
    }
    if (professionalProfileId != null) {
      insertPayload['professional_profile_id'] = professionalProfileId;
      insertPayload['author_profile_type'] = 'professional';
      insertPayload['author_profile_id'] = professionalProfileId;
    }
    if (eventId != null) {
      insertPayload['event_id'] = eventId;
      insertPayload['author_profile_type'] = 'event';
      insertPayload['author_profile_id'] = eventId;
    }
    if (communityId != null) {
      insertPayload['community_id'] = communityId;
      if (businessId == null &&
          professionalProfileId == null &&
          eventId == null) {
        insertPayload['author_profile_type'] = 'community';
        insertPayload['author_profile_id'] = communityId;
      }
    }
    final resolvedVisibility = visibility == 'followers'
        ? 'followers'
        : 'public';
    insertPayload['visibility'] = resolvedVisibility;
    final bg = backgroundColor?.trim();
    if (bg != null && bg.isNotEmpty && bg != 'none') {
      insertPayload['background_color'] = bg;
    }
    insertPayload['publish_destination'] = publishDestination.value;

    final row = await _insertPostReturning(insertPayload);

    final postId = row['id'] as String;
    await PostMetadataService.syncForPost(postId, trimmed);

    var media = const <CommunityNewsMediaItem>[];
    Object? mediaError;
    if (files.isNotEmpty) {
      try {
        media = await CommunityNewsMediaService.uploadMedia(
          postId: postId,
          files: files,
        );
      } catch (error) {
        mediaError = error;
      }
    }

    final authorNames = await _fetchProfileNames([me.id]);
    final authorUsernames = await _fetchProfileUsernames([me.id]);
    final insertedBusinessId = row['business_id'] as String?;
    final insertedCommunityId = row['community_id'] as String?;
    final insertedProfessionalId = row['professional_profile_id'] as String?;
    final insertedEventId = row['event_id'] as String?;
    String? contextName;
    String? communityName;
    String? communityImageUrl;
    if (insertedBusinessId != null) {
      contextName = (await _fetchBusinessNames([
        insertedBusinessId,
      ]))[insertedBusinessId];
    } else if (insertedProfessionalId != null) {
      contextName = (await _fetchProfessionalNames([
        insertedProfessionalId,
      ]))[insertedProfessionalId];
    } else if (insertedEventId != null) {
      contextName = (await _fetchEventTitles([
        insertedEventId,
      ]))[insertedEventId];
    } else if (insertedCommunityId != null) {
      communityName = (await _fetchCommunityNames([
        insertedCommunityId,
      ]))[insertedCommunityId];
      communityImageUrl = (await _fetchCommunityImages([
        insertedCommunityId,
      ]))[insertedCommunityId];
    }

    String? insertedBackground;
    try {
      final rawBg = row['background_color'] as String?;
      if (rawBg != null && rawBg.trim().isNotEmpty && rawBg != 'none') {
        insertedBackground = rawBg.trim();
      }
    } catch (_) {
      insertedBackground = bg != null && bg.isNotEmpty && bg != 'none'
          ? bg
          : null;
    }

    final post = CommunityNewsPost(
      id: postId,
      body: row['body'] as String,
      authorId: me.id,
      authorName: authorNames[me.id] ?? 'FirstVue member',
      authorUsername: authorUsernames[me.id],
      authorProfileType: row['author_profile_type'] as String?,
      businessId: insertedBusinessId,
      businessName: contextName,
      professionalProfileId: insertedProfessionalId,
      eventId: insertedEventId,
      communityId: insertedCommunityId,
      communityName: communityName,
      communityImageUrl: communityImageUrl,
      createdAt: DateTime.parse(row['created_at'] as String),
      isMine: true,
      sparkCount: 0,
      sparkedByMe: false,
      savedByMe: false,
      visibility: (row['visibility'] as String?) ?? resolvedVisibility,
      backgroundColor: insertedBackground,
      publishDestination: PublishDestination.parse(
        row['publish_destination'] as String? ?? publishDestination.value,
      ),
      media: media,
    );

    if (mediaError != null && files.isNotEmpty && media.isEmpty) {
      throw CommunityNewsMediaUploadException(post, mediaError);
    }

    return post;
  }

  static Future<CommunityNewsPost> toggleSave(CommunityNewsPost post) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to save posts.');

    await _ensureProfile(me);

    final saved = await SavedItemsService.toggleSave(
      contentType: SavedContentType.newsPost,
      contentId: post.id,
      currentlySaved: post.savedByMe,
    );
    return post.copyWith(savedByMe: saved);
  }

  /// Approved personal posts by a member (excludes Business/Professional posts).
  static Future<List<CommunityNewsPost>> fetchPostsByAuthor(
    String authorId, {
    int limit = 20,
    DateTime? beforeCreatedAt,
    String? beforeId,
  }) async {
    if (authorId.trim().isEmpty) return const [];

    final me = _client.auth.currentUser?.id;

    try {
      final rows = await _selectPosts((query) {
        var q = query
            .eq('author_id', authorId)
            .filter('business_id', 'is', null)
            .filter('professional_profile_id', 'is', null)
            .order('created_at', ascending: false)
            .limit(limit);
        if (beforeCreatedAt != null) {
          q = q.lt('created_at', beforeCreatedAt.toUtc().toIso8601String());
        }
        return q;
      });

      final mapped = await _mapPostRows(rows, currentUserId: me);
      if (beforeId == null || beforeId.isEmpty) return mapped;
      return mapped.where((post) => post.id != beforeId).toList();
    } catch (_) {
      try {
        final rows = await _selectPosts((query) {
          var q = query
              .eq('author_id', authorId)
              .order('created_at', ascending: false)
              .limit(limit);
          if (beforeCreatedAt != null) {
            q = q.lt('created_at', beforeCreatedAt.toUtc().toIso8601String());
          }
          return q;
        });
        final mapped = await _mapPostRows(rows, currentUserId: me);
        return mapped
            .where((p) => p.businessName == null)
            .where((p) => beforeId == null || p.id != beforeId)
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  static Future<List<CommunityNewsPost>> fetchPostsForBusiness(
    String businessId, {
    int limit = 20,
  }) async {
    if (businessId.trim().isEmpty) return const [];
    final me = _client.auth.currentUser?.id;
    try {
      final rows = await _selectPosts(
        (query) => query
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return await _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityNewsPost>> fetchPostsForProfessional(
    String professionalProfileId, {
    int limit = 20,
  }) async {
    if (professionalProfileId.trim().isEmpty) return const [];
    final me = _client.auth.currentUser?.id;
    try {
      final rows = await _selectPosts(
        (query) => query
            .eq('professional_profile_id', professionalProfileId)
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return await _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityNewsPost>> fetchPostsForEvent(
    String eventId, {
    int limit = 20,
  }) async {
    if (eventId.trim().isEmpty) return const [];
    final me = _client.auth.currentUser?.id;
    try {
      final rows = await _selectPosts(
        (query) => query
            .eq('event_id', eventId)
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return await _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityNewsPost>> fetchPostsForCommunity(
    String communityId, {
    int limit = 20,
  }) async {
    if (communityId.trim().isEmpty) return const [];
    final me = _client.auth.currentUser?.id;
    try {
      final rows = await _selectPosts(
        (query) => query
            .eq('community_id', communityId)
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return await _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      return const [];
    }
  }

  /// Posts from communities the signed-in user joined or follows.
  /// Separate from the broad Home News Feed (`fetchPosts`).
  static Future<List<CommunityNewsPost>> fetchCommunityFeed({
    int limit = 20,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];

    try {
      final communityIds = await CommunityService.fetchMyCommunityFeedIds();
      if (communityIds.isEmpty) return const [];

      final rows = await _selectPosts(
        (query) => query
            .inFilter('community_id', communityIds.toList())
            .order('created_at', ascending: false)
            .limit(limit),
      );
      return await _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      return const [];
    }
  }

  /// Post count and sparks received on the signed-in user's posts.
  static Future<ProfileEngagementStats> fetchMyEngagementStats() async {
    final me = _client.auth.currentUser;
    if (me == null) {
      return const ProfileEngagementStats(postCount: 0, sparksReceived: 0);
    }

    try {
      final posts = await _client
          .from('community_news_posts')
          .select('id')
          .eq('author_id', me.id);
      final postIds = posts
          .map((row) => row['id'] as String)
          .toList(growable: false);
      final postCount = postIds.length;

      if (postIds.isEmpty) {
        return ProfileEngagementStats(postCount: postCount, sparksReceived: 0);
      }

      final sparkRows = await _client
          .from('community_news_post_sparks')
          .select('post_id')
          .inFilter('post_id', postIds);
      return ProfileEngagementStats(
        postCount: postCount,
        sparksReceived: sparkRows.length,
      );
    } catch (_) {
      return const ProfileEngagementStats(postCount: 0, sparksReceived: 0);
    }
  }

  /// Post count and sparks received for any member's posts.
  static Future<ProfileEngagementStats> fetchEngagementStatsForAuthor(
    String authorId,
  ) async {
    if (authorId.trim().isEmpty) {
      return const ProfileEngagementStats(postCount: 0, sparksReceived: 0);
    }

    try {
      final posts = await _client
          .from('community_news_posts')
          .select('id')
          .eq('author_id', authorId);
      final postIds = posts
          .map((row) => row['id'] as String)
          .toList(growable: false);
      final postCount = postIds.length;

      if (postIds.isEmpty) {
        return ProfileEngagementStats(postCount: postCount, sparksReceived: 0);
      }

      final sparkRows = await _client
          .from('community_news_post_sparks')
          .select('post_id')
          .inFilter('post_id', postIds);
      return ProfileEngagementStats(
        postCount: postCount,
        sparksReceived: sparkRows.length,
      );
    } catch (_) {
      return const ProfileEngagementStats(postCount: 0, sparksReceived: 0);
    }
  }

  static Future<void> deletePost(String postId) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to delete posts.');

    await _client
        .from('community_news_posts')
        .delete()
        .eq('id', postId)
        .eq('author_id', me.id);
  }

  static Future<CommunityNewsPost> toggleSpark(CommunityNewsPost post) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to spark posts.');

    await _ensureProfile(me);

    if (post.sparkedByMe) {
      await _client
          .from('community_news_post_sparks')
          .delete()
          .eq('post_id', post.id)
          .eq('user_id', me.id);
      return post.copyWith(
        sparkedByMe: false,
        sparkCount: post.sparkCount > 0 ? post.sparkCount - 1 : 0,
      );
    }

    await _client.from('community_news_post_sparks').insert({
      'post_id': post.id,
      'user_id': me.id,
    });

    if (!post.isMine) {
      try {
        final author = await _client
            .from('community_news_posts')
            .select('author_id')
            .eq('id', post.id)
            .maybeSingle();
        final recipient = author?['author_id'] as String?;
        if (recipient != null && recipient != me.id) {
          await ActivityNotificationsService.notifyUser(
            userId: recipient,
            type: 'news_spark',
            title: 'Someone sparked your news post',
            body: post.body,
            payload: {'post_id': post.id},
          );
        }
      } catch (_) {}
    }

    return post.copyWith(sparkedByMe: true, sparkCount: post.sparkCount + 1);
  }

  static Future<List<SparkUser>> fetchSparkUsers(
    String postId, {
    int limit = 30,
    int offset = 0,
  }) async {
    if (postId.trim().isEmpty) return const [];
    try {
      final rows = await _client
          .from('community_news_post_sparks')
          .select('user_id')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final ids = rows.map((row) => row['user_id'] as String).toList();
      if (ids.isEmpty) return const [];

      final profiles = await _client
          .from('profiles')
          .select('id, display_name, username, avatar_url')
          .inFilter('id', ids);

      final byId = {for (final row in profiles) row['id'] as String: row};

      return ids.map((id) {
        final row = byId[id];
        if (row == null) {
          return SparkUser(id: id, displayName: 'FirstVue member');
        }
        return SparkUser(
          id: id,
          displayName: (row['display_name'] as String?) ?? 'FirstVue member',
          username: row['username'] as String?,
          avatarUrl: row['avatar_url'] as String?,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }
}

class SparkUser {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  const SparkUser({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });
}

class CommunityNewsMediaUploadException implements Exception {
  final CommunityNewsPost post;
  final Object cause;

  const CommunityNewsMediaUploadException(this.post, this.cause);

  @override
  String toString() => 'Post saved but media upload failed: $cause';
}
