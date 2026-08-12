import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_notifications_service.dart';
import 'community_news_media_service.dart';
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
  final String authorName;
  final String? businessName;
  final DateTime createdAt;
  final bool isMine;
  final int sparkCount;
  final bool sparkedByMe;
  final bool savedByMe;
  final List<CommunityNewsMediaItem> media;

  const CommunityNewsPost({
    required this.id,
    required this.body,
    required this.authorName,
    required this.businessName,
    required this.createdAt,
    required this.isMine,
    required this.sparkCount,
    required this.sparkedByMe,
    required this.savedByMe,
    this.media = const [],
  });

  String get commentsMediaId => 'news-post:$id';

  CommunityNewsPost copyWith({
    String? id,
    String? body,
    String? authorName,
    String? businessName,
    DateTime? createdAt,
    bool? isMine,
    int? sparkCount,
    bool? sparkedByMe,
    bool? savedByMe,
    List<CommunityNewsMediaItem>? media,
  }) {
    return CommunityNewsPost(
      id: id ?? this.id,
      body: body ?? this.body,
      authorName: authorName ?? this.authorName,
      businessName: businessName ?? this.businessName,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      sparkCount: sparkCount ?? this.sparkCount,
      sparkedByMe: sparkedByMe ?? this.sparkedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
      media: media ?? this.media,
    );
  }
}

class CommunityNewsService {
  CommunityNewsService._();

  static final _client = Supabase.instance.client;

  static Future<List<CommunityNewsPost>> fetchPosts({int limit = 20}) async {
    final me = _client.auth.currentUser?.id;
    // RLS returns approved posts plus the signed-in author's own posts.
    final rows = await _client
        .from('community_news_posts')
        .select('id, body, created_at, author_id, business_id')
        .order('created_at', ascending: false)
        .limit(limit);

    return _mapPostRows(rows, currentUserId: me);
  }

  /// Posts authored by the signed-in user (any status), for profile display.
  static Future<List<CommunityNewsPost>> fetchMyPosts({int limit = 10}) async {
    final me = _client.auth.currentUser;
    if (me == null) return const [];

    try {
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, author_id, business_id')
          .eq('author_id', me.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return _mapPostRows(rows, currentUserId: me.id);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CommunityNewsPost>> _mapPostRows(
    List<dynamic> rows, {
    required String? currentUserId,
  }) async {
    if (rows.isEmpty) return const [];

    final postIds = rows.map((row) => row['id'] as String).toList();
    final authorIds =
        rows.map((row) => row['author_id'] as String).toSet().toList();
    final businessIds = rows
        .map((row) => row['business_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final authorNames = await _fetchProfileNames(authorIds);
    final businessNames = await _fetchBusinessNames(businessIds);
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

    return rows.map((row) {
      final id = row['id'] as String;
      final authorId = row['author_id'] as String;
      final businessId = row['business_id'] as String?;
      final createdRaw = row['created_at'];
      final createdAt = createdRaw is String
          ? DateTime.tryParse(createdRaw) ?? DateTime.now()
          : DateTime.now();
      return CommunityNewsPost(
        id: id,
        body: (row['body'] as String?) ?? '',
        authorName: authorNames[authorId] ?? 'FirstVue member',
        businessName:
            businessId == null ? null : businessNames[businessId],
        createdAt: createdAt,
        isMine: authorId == currentUserId,
        sparkCount: sparkCounts[id] ?? 0,
        sparkedByMe: mySparks.contains(id),
        savedByMe: mySaves.contains(id),
        media: mediaByPost[id] ?? const [],
      );
    }).toList();
  }

  static String normalizePostId(String raw) {
    final trimmed = raw.trim();
    const prefix = 'news-post:';
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }
    return trimmed;
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
      final rows = await _client
          .from('community_news_posts')
          .select('id, body, created_at, author_id, business_id')
          .eq('id', postId)
          .limit(1);

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
    List<XFile> files = const [],
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to post.');
    final trimmed = body.trim();
    if (trimmed.isEmpty && files.isEmpty) {
      throw ArgumentError('Add text or attach a photo/video.');
    }

    await _ensureProfile(me);

    final row = await _client
        .from('community_news_posts')
        .insert({
          'author_id': me.id,
          'business_id': businessId,
          'body': trimmed,
          'status': 'approved',
        })
        .select('id, body, created_at, author_id, business_id')
        .single();

    final postId = row['id'] as String;
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
    final insertedBusinessId = row['business_id'] as String?;
    final businessNames = insertedBusinessId == null
        ? const <String, String>{}
        : await _fetchBusinessNames([insertedBusinessId]);

    final post = CommunityNewsPost(
      id: postId,
      body: row['body'] as String,
      authorName: authorNames[me.id] ?? 'FirstVue member',
      businessName: insertedBusinessId == null
          ? null
          : businessNames[insertedBusinessId],
      createdAt: DateTime.parse(row['created_at'] as String),
      isMine: true,
      sparkCount: 0,
      sparkedByMe: false,
      savedByMe: false,
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
}

class CommunityNewsMediaUploadException implements Exception {
  final CommunityNewsPost post;
  final Object cause;

  const CommunityNewsMediaUploadException(this.post, this.cause);

  @override
  String toString() => 'Post saved but media upload failed: $cause';
}
