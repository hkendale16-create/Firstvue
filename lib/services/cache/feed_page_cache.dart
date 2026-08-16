import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/media_config.dart';
import '../../models/publish_destination.dart';
import '../community_news_media_service.dart';
import '../community_news_service.dart';
import 'cache_ttls.dart';
import 'ttl_memory_cache.dart';

/// Session + light disk cache for Home feed pages and previously viewed posts.
class FeedPageCache {
  FeedPageCache._();

  static const _prefsKey = 'firstvue_feed_page_main_v1';
  static const _maxPersistedPosts = 20;

  static final _rankedPages = TtlMemoryCache<List<CommunityNewsPost>>(
    ttl: CacheTtls.feedPage,
    maxEntries: 8,
    name: 'feed_pages',
  );

  static final _viewedPosts = TtlMemoryCache<CommunityNewsPost>(
    ttl: CacheTtls.viewedPost,
    maxEntries: 80,
    name: 'viewed_posts',
  );

  static String rankedKey({required int limit, required double seed}) {
    // Bucket seed so tiny float differences do not explode cache keys.
    final seedBucket = (seed / 1000).floor();
    return 'ranked:$limit:$seedBucket';
  }

  static List<CommunityNewsPost>? getRankedFresh({
    required int limit,
    required double seed,
  }) {
    return _rankedPages.getFresh(rankedKey(limit: limit, seed: seed));
  }

  static List<CommunityNewsPost>? peekRanked({
    required int limit,
    required double seed,
  }) {
    return _rankedPages.peek(rankedKey(limit: limit, seed: seed));
  }

  static void putRanked({
    required int limit,
    required double seed,
    required List<CommunityNewsPost> posts,
  }) {
    _rankedPages.put(rankedKey(limit: limit, seed: seed), posts);
    for (final post in posts) {
      rememberViewed(post);
    }
    // Persist a compact first-page snapshot for cold reopen (best-effort).
    if (limit <= 40) {
      unawaited(_persistMainFeed(posts));
    }
  }

  static void rememberViewed(CommunityNewsPost post) {
    _viewedPosts.put(post.id, post);
  }

  static CommunityNewsPost? getViewed(String postId) {
    return _viewedPosts.getFresh(postId) ?? _viewedPosts.peek(postId);
  }

  static Future<List<CommunityNewsPost>> loadPersistedMainFeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final atMs = decoded['at'] as int?;
      if (atMs == null) return const [];
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(atMs),
      );
      // Disk snapshot is useful for instant reopen only while reasonably fresh.
      if (age > const Duration(hours: 6)) return const [];
      final postsRaw = decoded['posts'];
      if (postsRaw is! List) return const [];
      final posts = <CommunityNewsPost>[];
      for (final entry in postsRaw.take(_maxPersistedPosts)) {
        if (entry is! Map) continue;
        final post = _decodePost(Map<String, dynamic>.from(entry));
        if (post != null) posts.add(post);
      }
      return posts;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _persistMainFeed(List<CommunityNewsPost> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'at': DateTime.now().millisecondsSinceEpoch,
        'posts': [
          for (final post in posts.take(_maxPersistedPosts)) _encodePost(post),
        ],
      };
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // Disk cache is best-effort.
    }
  }

  static Future<void> clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  static void clear() {
    _rankedPages.clear();
    _viewedPosts.clear();
    unawaited(clearPersisted());
  }

  static Map<String, dynamic> _encodePost(CommunityNewsPost post) {
    return {
      'id': post.id,
      'body': post.body,
      'author_id': post.authorId,
      'author_name': post.authorName,
      'author_username': post.authorUsername,
      'author_profile_type': post.authorProfileType,
      'author_profile_id': post.authorProfileId,
      'business_id': post.businessId,
      'business_name': post.businessName,
      'business_type': post.businessType,
      'professional_profile_id': post.professionalProfileId,
      'event_id': post.eventId,
      'community_id': post.communityId,
      'community_name': post.communityName,
      'community_image_url': post.communityImageUrl,
      'created_at': post.createdAt.toIso8601String(),
      'is_mine': post.isMine,
      'viewer_follows_author': post.viewerFollowsAuthor,
      'spark_count': post.sparkCount,
      'sparked_by_me': post.sparkedByMe,
      'my_reaction_type': post.myReactionType,
      'entity_handle': post.entityHandle,
      'saved_by_me': post.savedByMe,
      'repost_count': post.repostCount,
      'reposted_by_me': post.repostedByMe,
      'visibility': post.visibility,
      'background_color': post.backgroundColor,
      'publish_destination': post.publishDestination.name,
      'business_services': post.businessServices,
      'industry_slug': post.industrySlug,
      'media': [
        for (final m in post.media)
          {
            'id': m.id,
            'storage_path': m.storagePath,
            'signed_url': m.signedUrl,
            'storage_provider': m.storageProvider.value,
            'media_type': m.mediaType,
            'storage_bucket': m.storageBucket.id,
          },
      ],
    };
  }

  static CommunityNewsPost? _decodePost(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    final body = map['body'] as String?;
    final authorId = map['author_id'] as String?;
    final authorName = map['author_name'] as String?;
    final createdRaw = map['created_at'] as String?;
    if (id == null ||
        body == null ||
        authorId == null ||
        authorName == null ||
        createdRaw == null) {
      return null;
    }
    final createdAt = DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;

    final mediaRaw = map['media'];
    final media = <CommunityNewsMediaItem>[];
    if (mediaRaw is List) {
      for (final entry in mediaRaw) {
        if (entry is! Map) continue;
        final mid = entry['id'] as String?;
        final path = entry['storage_path'] as String?;
        final url = entry['signed_url'] as String?;
        if (mid == null || path == null || url == null) continue;
        media.add(
          CommunityNewsMediaItem(
            id: mid,
            storagePath: path,
            signedUrl: url,
            storageProvider: MediaStorageProvider.parse(
              entry['storage_provider'] as String?,
            ),
            mediaType: (entry['media_type'] as String?) ?? 'image',
            storageBucket: MediaBucket.fromId(
              entry['storage_bucket'] as String?,
            ),
          ),
        );
      }
    }

    return CommunityNewsPost(
      id: id,
      body: body,
      authorId: authorId,
      authorName: authorName,
      authorUsername: map['author_username'] as String?,
      authorProfileType: map['author_profile_type'] as String?,
      authorProfileId: map['author_profile_id'] as String?,
      businessId: map['business_id'] as String?,
      businessName: map['business_name'] as String?,
      businessType: map['business_type'] as String?,
      professionalProfileId: map['professional_profile_id'] as String?,
      eventId: map['event_id'] as String?,
      communityId: map['community_id'] as String?,
      communityName: map['community_name'] as String?,
      communityImageUrl: map['community_image_url'] as String?,
      createdAt: createdAt,
      isMine: map['is_mine'] as bool? ?? false,
      viewerFollowsAuthor: map['viewer_follows_author'] as bool? ?? false,
      sparkCount: (map['spark_count'] as num?)?.toInt() ?? 0,
      sparkedByMe: map['sparked_by_me'] as bool? ?? false,
      myReactionType: map['my_reaction_type'] as String?,
      entityHandle: map['entity_handle'] as String?,
      savedByMe: map['saved_by_me'] as bool? ?? false,
      repostCount: (map['repost_count'] as num?)?.toInt() ?? 0,
      repostedByMe: map['reposted_by_me'] as bool? ?? false,
      visibility: (map['visibility'] as String?) ?? 'public',
      backgroundColor: map['background_color'] as String?,
      publishDestination: PublishDestination.values.firstWhere(
        (d) => d.name == map['publish_destination'],
        orElse: () => PublishDestination.feed,
      ),
      media: media,
      businessServices: List<String>.from(
        (map['business_services'] as List?) ?? const [],
      ),
      industrySlug: map['industry_slug'] as String?,
    );
  }
}
