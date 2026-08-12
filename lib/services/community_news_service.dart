import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';
import 'community_news_media_service.dart';
import 'follow_service.dart';
import 'post_metadata_service.dart';
import 'saved_items_service.dart';

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
  final String? businessName;
  final DateTime createdAt;
  final bool isMine;
  final int sparkCount;
  final bool sparkedByMe;
  final bool savedByMe;
  final int repostCount;
  final String visibility;
  final List<CommunityNewsMediaItem> media;

  const CommunityNewsPost({
    required this.id,
    required this.body,
    required this.authorId,
    required this.authorName,
    this.authorUsername,
    required this.businessName,
    required this.createdAt,
    required this.isMine,
    required this.sparkCount,
    required this.sparkedByMe,
    required this.savedByMe,
    this.repostCount = 0,
    this.visibility = 'public',
    this.media = const [],
  });

  String get commentsMediaId => 'news-post:$id';

  CommunityNewsPost copyWith({
    String? id,
    String? body,
    String? authorId,
    String? authorName,
    String? authorUsername,
    String? businessName,
    DateTime? createdAt,
    bool? isMine,
    int? sparkCount,
    bool? sparkedByMe,
    bool? savedByMe,
    int? repostCount,
    String? visibility,
    List<CommunityNewsMediaItem>? media,
  }) {
    return CommunityNewsPost(
      id: id ?? this.id,
      body: body ?? this.body,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorUsername: authorUsername ?? this.authorUsername,
      businessName: businessName ?? this.businessName,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      sparkCount: sparkCount ?? this.sparkCount,
      sparkedByMe: sparkedByMe ?? this.sparkedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
      repostCount: repostCount ?? this.repostCount,
      visibility: visibility ?? this.visibility,
      media: media ?? this.media,
    );
  }
}

class CommunityNewsService {
  CommunityNewsService._();

  static final _client = Supabase.instance.client;

  static const _postColumns =
      'id, body, created_at, author_id, business_id, community_id, visibility, professional_profile_id, event_id';

  static const _postColumnsBase =
      'id, body, created_at, author_id, business_id, community_id';

  /// Builds a select query with filters applied *after* `.select()`.
  ///
  /// Calling `.order` / `.eq` / `.limit` on the pre-select builder (and
  /// discarding the returned filter builder) breaks Home News Feed loading.
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

  static Future<Map<String, dynamic>> _insertPostReturning(
    Map<String, dynamic> insertPayload,
  ) async {
    try {
      return await _client
          .from('community_news_posts')
          .insert(insertPayload)
          .select(_postColumns)
          .single();
    } catch (_) {
      return await _client
          .from('community_news_posts')
          .insert(insertPayload)
          .select(_postColumnsBase)
          .single();
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
    final canViewFull = isMine ||
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

  static Future<List<CommunityNewsPost>> fetchPosts({int limit = 20}) async {
    final me = _client.auth.currentUser?.id;
    try {
      // RLS returns approved posts plus the signed-in author's own posts.
      final rows = await _selectPosts(
        (query) => query.order('created_at', ascending: false).limit(limit),
      );
      return await _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      // Keep the Home News Feed usable even if enrichment fails.
      try {
        final rows = await _selectPosts(
          (query) => query.order('created_at', ascending: false).limit(limit),
        );
        return await _mapPostRowsMinimal(rows, currentUserId: me);
      } catch (_) {
        return const [];
      }
    }
  }

  /// Posts authored by the signed-in user (any status), for profile display.
  static Future<List<CommunityNewsPost>> fetchMyPosts({int limit = 10}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final rows = await _selectPosts(
        (query) => query
            .eq('author_id', me.id)
            .order('created_at', ascending: false)
            .limit(limit),
      );

      return _mapPostRows(rows, currentUserId: me.id);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityNewsPost>> _mapPostRowsMinimal(
    List<dynamic> rows, {
    required String? currentUserId,
  }) async {
    if (rows.isEmpty) return const [];
    final posts = <CommunityNewsPost>[];
    for (final row in rows) {
      try {
        final id = row['id'] as String?;
        final authorId = row['author_id'] as String?;
        if (id == null || authorId == null) continue;
        final createdRaw = row['created_at'];
        posts.add(
          CommunityNewsPost(
            id: id,
            body: (row['body'] as String?) ?? '',
            authorId: authorId,
            authorName: 'FirstVue member',
            businessName: null,
            createdAt: createdRaw is String
                ? DateTime.tryParse(createdRaw) ?? DateTime.now()
                : createdRaw is DateTime
                    ? createdRaw
                    : DateTime.now(),
            isMine: authorId == currentUserId,
            sparkCount: 0,
            sparkedByMe: false,
            savedByMe: false,
            visibility: (row['visibility'] as String?) ?? 'public',
          ),
        );
      } catch (_) {
        // Skip malformed rows so one bad post cannot blank the feed.
      }
    }
    return posts;
  }

  static Future<List<CommunityNewsPost>> _mapPostRows(
    List<dynamic> rows, {
    required String? currentUserId,
  }) async {
    if (rows.isEmpty) return const [];

    final postIds = <String>[];
    final authorIds = <String>{};
    final businessIds = <String>{};
    final communityIds = <String>{};
    final professionalIds = <String>{};
    final eventIds = <String>{};

    for (final row in rows) {
      final id = row['id'] as String?;
      final authorId = row['author_id'] as String?;
      if (id == null || authorId == null) continue;
      postIds.add(id);
      authorIds.add(authorId);
      final businessId = row['business_id'] as String?;
      final communityId = row['community_id'] as String?;
      final professionalProfileId = row['professional_profile_id'] as String?;
      final eventId = row['event_id'] as String?;
      if (businessId != null) businessIds.add(businessId);
      if (communityId != null) communityIds.add(communityId);
      if (professionalProfileId != null) {
        professionalIds.add(professionalProfileId);
      }
      if (eventId != null) eventIds.add(eventId);
    }

    if (postIds.isEmpty) return const [];

    final authorNames = await _fetchProfileNames(authorIds.toList());
    final authorUsernames = await _fetchProfileUsernames(authorIds.toList());
    final businessNames = await _fetchBusinessNames(businessIds.toList());
    final communityNames = await _fetchCommunityNames(communityIds.toList());
    final professionalNames =
        await _fetchProfessionalNames(professionalIds.toList());
    final eventTitles = await _fetchEventTitles(eventIds.toList());
    final sparkCounts = await _fetchSparkCounts(postIds);
    final mySparks = currentUserId == null
        ? const <String>{}
        : await _fetchMySparks(postIds, currentUserId);
    Set<String> mySaves = const {};
    try {
      mySaves = currentUserId == null
          ? const <String>{}
          : await SavedItemsService.fetchSavedIds(
              contentType: SavedContentType.newsPost,
              contentIds: postIds,
            );
    } catch (_) {
      mySaves = const {};
    }
    Map<String, List<CommunityNewsMediaItem>> mediaByPost = const {};
    try {
      mediaByPost = await CommunityNewsMediaService.fetchMediaByPostIds(
        postIds,
      );
    } catch (_) {
      mediaByPost = const {};
    }
    final followingAuthors = await _followingAuthorIds(
      authorIds.toList(),
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
            ? businessNames[businessId]
            : professionalProfileId != null
                ? professionalNames[professionalProfileId]
                : eventId != null
                    ? eventTitles[eventId]
                    : (communityId != null
                        ? communityNames[communityId]
                        : null);
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
        posts.add(
          CommunityNewsPost(
            id: id,
            body: body,
            authorId: authorId,
            authorName: authorNames[authorId] ?? 'FirstVue member',
            authorUsername: authorUsernames[authorId],
            businessName: contextName,
            createdAt: createdAt,
            isMine: isMine,
            sparkCount: sparkCounts[id] ?? 0,
            sparkedByMe: mySparks.contains(id),
            savedByMe: mySaves.contains(id),
            visibility: visibility,
            media: media,
          ),
        );
      } catch (_) {
        // Skip one broken row; keep loading the rest of the News Feed.
      }
    }
    return posts;
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
    if (businessIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('businesses')
          .select('id, name')
          .inFilter('id', businessIds);
      return {
        for (final row in rows)
          row['id'] as String: row['name'] as String,
      };
    } catch (_) {
      return {};
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
        for (final row in rows)
          row['id'] as String: row['name'] as String,
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
        for (final row in rows)
          row['id'] as String: row['title'] as String,
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
        throw const AuthException('You can only post for businesses you manage.');
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

  static Future<Map<String, int>> _fetchSparkCounts(List<String> postIds) async {
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
    };
    if (businessId != null) insertPayload['business_id'] = businessId;
    if (communityId != null) insertPayload['community_id'] = communityId;
    if (professionalProfileId != null) {
      insertPayload['professional_profile_id'] = professionalProfileId;
    }
    if (eventId != null) insertPayload['event_id'] = eventId;

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
    if (insertedBusinessId != null) {
      contextName =
          (await _fetchBusinessNames([insertedBusinessId]))[insertedBusinessId];
    } else if (insertedProfessionalId != null) {
      contextName = (await _fetchProfessionalNames([insertedProfessionalId]))[
          insertedProfessionalId];
    } else if (insertedEventId != null) {
      contextName =
          (await _fetchEventTitles([insertedEventId]))[insertedEventId];
    } else if (insertedCommunityId != null) {
      contextName =
          (await _fetchCommunityNames([insertedCommunityId]))[insertedCommunityId];
    }

    final post = CommunityNewsPost(
      id: postId,
      body: row['body'] as String,
      authorId: me.id,
      authorName: authorNames[me.id] ?? 'FirstVue member',
      authorUsername: authorUsernames[me.id],
      businessName: contextName,
      createdAt: DateTime.parse(row['created_at'] as String),
      isMine: true,
      sparkCount: 0,
      sparkedByMe: false,
      savedByMe: false,
      visibility: (row['visibility'] as String?) ?? 'public',
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

  /// Approved posts by a member (RLS also allows viewing own pending posts).
  static Future<List<CommunityNewsPost>> fetchPostsByAuthor(
    String authorId, {
    int limit = 20,
  }) async {
    if (authorId.trim().isEmpty) return const [];

    final me = _client.auth.currentUser?.id;

    try {
      final rows = await _selectPosts(
        (query) => query
            .eq('author_id', authorId)
            .order('created_at', ascending: false)
            .limit(limit),
      );

      return _mapPostRows(rows, currentUserId: me);
    } catch (_) {
      return const [];
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
      return _mapPostRows(rows, currentUserId: me);
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
      return _mapPostRows(rows, currentUserId: me);
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
      return _mapPostRows(rows, currentUserId: me);
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
      final postIds =
          posts.map((row) => row['id'] as String).toList(growable: false);
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
      final postIds =
          posts.map((row) => row['id'] as String).toList(growable: false);
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

    return post.copyWith(
      sparkedByMe: true,
      sparkCount: post.sparkCount + 1,
    );
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

      final byId = {
        for (final row in profiles) row['id'] as String: row,
      };

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
