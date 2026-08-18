import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_environment.dart';
import 'community_news_service.dart';
import 'discovery_feed_service.dart';
import 'feed_interaction_service.dart';
import 'post_impressions_service.dart';
import 'saved_items_service.dart';
import 'vue_feed_ranking.dart';

/// Batch VUE engagement summaries + legitimate view/play/like/share writes.
///
/// Hydration is one RPC per page (not per tile). View and play writes are
/// debounced in-memory and again in SQL so rebuilds cannot inflate counts.
class VueEngagementService {
  VueEngagementService._();

  static final _client = Supabase.instance.client;
  static const _viewDebounce = Duration(hours: 24);
  static const _playDebounce = Duration(seconds: 30);
  static final Map<String, DateTime> _lastView = {};
  static final Map<String, DateTime> _lastPlay = {};
  static final Map<String, DateTime> _lastLike = {};

  static void clearDebounceCache() {
    _lastView.clear();
    _lastPlay.clear();
    _lastLike.clear();
  }

  static Future<List<DiscoveryFeedItem>> hydrate(
    List<DiscoveryFeedItem> items,
  ) async {
    if (items.isEmpty || isWidgetTestBinding) return items;
    try {
      final mediaIds = items.map((item) => item.mediaId).toList();
      final newsPostIds = items
          .map((item) => item.newsPostId ?? '')
          .toList(growable: false);
      final rows = await _client.rpc(
        'fetch_vue_engagement_summaries',
        params: {
          'p_media_ids': mediaIds,
          'p_news_post_ids': newsPostIds,
        },
      );
      if (rows is! List || rows.isEmpty) {
        return assignVueTrendingRanks(items);
      }
      final byId = <String, Map<String, dynamic>>{
        for (final raw in rows)
          if (raw is Map)
            (raw['media_id'] as String? ?? ''): Map<String, dynamic>.from(raw),
      };
      final hydrated = [
        for (final item in items)
          _applySummary(item, byId[item.mediaId]),
      ];
      return assignVueTrendingRanks(hydrated);
    } catch (_) {
      return assignVueTrendingRanks(await _hydrateFallback(items));
    }
  }

  static DiscoveryFeedItem _applySummary(
    DiscoveryFeedItem item,
    Map<String, dynamic>? row,
  ) {
    if (row == null) return item;
    int n(String key) => (row[key] as num?)?.toInt() ?? 0;
    return item.copyWith(
      likesCount: n('likes_count'),
      commentsCount: n('comments_count'),
      sharesCount: n('shares_count'),
      savesCount: n('saves_count'),
      viewsCount: n('views_count'),
      playsCount: n('plays_count'),
      recentLikesCount: n('recent_likes'),
      recentCommentsCount: n('recent_comments'),
      recentSharesCount: n('recent_shares'),
      recentSavesCount: n('recent_saves'),
      recentViewsCount: n('recent_views'),
      recentPlaysCount: n('recent_plays'),
      userHasLiked: row['user_has_liked'] == true,
      userHasSaved: row['user_has_saved'] == true,
      myReactionType: row['my_reaction'] as String?,
      clearReaction: row['my_reaction'] == null,
    );
  }

  /// Limited fallback: comment counts + news-post sparks + save flags.
  /// Does not scan feed_engagements (RLS is own-row only).
  static Future<List<DiscoveryFeedItem>> _hydrateFallback(
    List<DiscoveryFeedItem> items,
  ) async {
    try {
      final commentKeys = items.map((item) => item.commentsMediaId).toList();
      final newsIds = items
          .map((item) => item.newsPostId)
          .whereType<String>()
          .toList();
      final me = _client.auth.currentUser?.id;

      final commentsFuture = _client
          .from('feed_comments')
          .select('media_id')
          .inFilter('media_id', commentKeys);
      final sparksFuture = newsIds.isEmpty
          ? Future.value(const <dynamic>[])
          : _client
              .from('community_news_post_sparks')
              .select('post_id, user_id, reaction_type')
              .inFilter('post_id', newsIds);
      final vueIds = items.map((item) => item.mediaId).toList();
      final savedFuture = me == null
          ? Future.value(const <String>{})
          : SavedItemsService.fetchSavedIds(
              contentType: SavedContentType.vueMedia,
              contentIds: vueIds,
            );
      final newsSavedFuture = me == null || newsIds.isEmpty
          ? Future.value(const <String>{})
          : SavedItemsService.fetchSavedIds(
              contentType: SavedContentType.newsPost,
              contentIds: newsIds,
            );

      final commentRows = await commentsFuture;
      final sparkRows = await sparksFuture;
      final vueSaved = await savedFuture;
      final newsSaved = await newsSavedFuture;

      final commentCounts = <String, int>{};
      for (final row in commentRows) {
        final id = row['media_id'] as String?;
        if (id == null) continue;
        commentCounts[id] = (commentCounts[id] ?? 0) + 1;
      }
      final sparkCounts = <String, int>{};
      final myReactions = <String, String>{};
      for (final row in sparkRows) {
        final id = row['post_id'] as String?;
        if (id == null) continue;
        sparkCounts[id] = (sparkCounts[id] ?? 0) + 1;
        if (me != null && row['user_id'] == me) {
          myReactions[id] = (row['reaction_type'] as String?) ?? 'spark';
        }
      }

      return [
        for (final item in items)
          item.copyWith(
            commentsCount: commentCounts[item.commentsMediaId] ?? 0,
            likesCount: item.newsPostId == null
                ? item.likesCount
                : (sparkCounts[item.newsPostId] ?? 0),
            userHasLiked: item.newsPostId == null
                ? item.userHasLiked
                : myReactions.containsKey(item.newsPostId),
            myReactionType: item.newsPostId == null
                ? item.myReactionType
                : myReactions[item.newsPostId],
            userHasSaved: item.newsPostId != null
                ? newsSaved.contains(item.newsPostId)
                : vueSaved.contains(item.mediaId),
            clearReaction: item.newsPostId != null &&
                !myReactions.containsKey(item.newsPostId),
          ),
      ];
    } catch (_) {
      return items;
    }
  }

  static bool _debounced(Map<String, DateTime> cache, String key, Duration window) {
    final now = DateTime.now();
    final last = cache[key];
    if (last != null && now.difference(last) < window) return true;
    cache[key] = now;
    return false;
  }

  static Future<bool> recordView(DiscoveryFeedItem item) async {
    if (isWidgetTestBinding) return false;
    final me = _client.auth.currentUser?.id;
    if (me == null) return false;
    if (_debounced(_lastView, '$me:${item.mediaId}', _viewDebounce)) {
      return false;
    }
    try {
      final result = await _client.rpc(
        'record_vue_engagement',
        params: {
          'p_media_id': item.mediaId,
          'p_event_type': 'view',
          'p_news_post_id': item.newsPostId,
        },
      );
      if (!_rpcRecorded(result)) return false;
    } catch (_) {
      _lastView.remove('$me:${item.mediaId}');
      return false;
    }
    if (item.newsPostId != null) {
      await PostImpressionsService.recordVisibleImpression(
        postId: item.newsPostId!,
        feedSource: 'vue',
      );
      await FeedInteractionService.record(
        postId: item.newsPostId!,
        interactionType: 'view',
        sourceTab: 'vue',
      );
    }
    return true;
  }

  static Future<bool> recordPlay(DiscoveryFeedItem item, {int watchMs = 0}) async {
    if (isWidgetTestBinding) return false;
    final me = _client.auth.currentUser?.id;
    if (me == null || !item.isVideo) return false;
    if (_debounced(_lastPlay, '$me:${item.mediaId}', _playDebounce)) {
      return false;
    }
    try {
      final result = await _client.rpc(
        'record_vue_engagement',
        params: {
          'p_media_id': item.mediaId,
          'p_event_type': 'play',
          'p_news_post_id': item.newsPostId,
          'p_watch_ms': watchMs,
        },
      );
      if (!_rpcRecorded(result)) return false;
      if (item.newsPostId != null) {
        await FeedInteractionService.record(
          postId: item.newsPostId!,
          interactionType: 'watch',
          sourceTab: 'vue',
          watchTimeMs: watchMs,
        );
      }
      return true;
    } catch (_) {
      _lastPlay.remove('$me:${item.mediaId}');
      return false;
    }
  }

  static Future<void> recordShare(DiscoveryFeedItem item) async {
    if (isWidgetTestBinding) return;
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      await _client.rpc(
        'record_vue_engagement',
        params: {
          'p_media_id': item.mediaId,
          'p_event_type': 'share',
          'p_news_post_id': item.newsPostId,
        },
      );
    } catch (_) {}
    if (item.newsPostId != null) {
      await FeedInteractionService.record(
        postId: item.newsPostId!,
        interactionType: 'share',
        sourceTab: 'vue',
      );
    }
  }

  static Future<DiscoveryFeedItem> toggleLike(DiscoveryFeedItem item) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to react.');
    if (_debounced(_lastLike, '${me.id}:${item.mediaId}', const Duration(milliseconds: 400))) {
      return item;
    }

    if (item.newsPostId != null) {
      final stub = CommunityNewsPost(
        id: item.newsPostId!,
        body: item.caption,
        authorId: item.ownerId,
        authorName: item.ownerName,
        businessName: item.businessName,
        createdAt: item.createdAt ?? DateTime.now(),
        isMine: item.ownerId == me.id,
        sparkCount: item.likesCount,
        sparkedByMe: item.userHasLiked,
        myReactionType: item.myReactionType,
        savedByMe: item.userHasSaved,
      );
      final updated = await CommunityNewsService.toggleSpark(stub);
      return item.copyWith(
        likesCount: updated.sparkCount,
        userHasLiked: updated.sparkedByMe,
        myReactionType: updated.myReactionType,
        clearReaction: updated.myReactionType == null,
      );
    }

    try {
      final result = await _client.rpc(
        'record_vue_engagement',
        params: {
          'p_media_id': item.mediaId,
          'p_event_type': 'like',
        },
      );
      final liked = _rpcFlag(result, 'user_has_liked');
      final nextLiked = liked;
      return item.copyWith(
        userHasLiked: nextLiked,
        likesCount: (item.likesCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 30),
        myReactionType: nextLiked ? PostReactionType.spark.value : null,
        clearReaction: !nextLiked,
      );
    } catch (_) {
      _lastLike.remove('${me.id}:${item.mediaId}');
      rethrow;
    }
  }

  static Future<DiscoveryFeedItem> setReaction(
    DiscoveryFeedItem item,
    PostReactionType type,
  ) async {
    final me = _client.auth.currentUser;
    if (me == null) throw const AuthException('Sign in to react.');
    if (item.newsPostId == null) {
      return toggleLike(item);
    }
    final stub = CommunityNewsPost(
      id: item.newsPostId!,
      body: item.caption,
      authorId: item.ownerId,
      authorName: item.ownerName,
      businessName: item.businessName,
      createdAt: item.createdAt ?? DateTime.now(),
      isMine: item.ownerId == me.id,
      sparkCount: item.likesCount,
      sparkedByMe: item.userHasLiked,
      myReactionType: item.myReactionType,
      savedByMe: item.userHasSaved,
    );
    final updated = await CommunityNewsService.setReaction(stub, type);
    return item.copyWith(
      likesCount: updated.sparkCount,
      userHasLiked: updated.sparkedByMe,
      myReactionType: updated.myReactionType,
      clearReaction: updated.myReactionType == null,
    );
  }

  static bool _rpcRecorded(dynamic result) => _rpcFlag(result, 'recorded');

  static bool _rpcFlag(dynamic result, String key) {
    if (result is Map) return result[key] == true;
    return false;
  }

  static Future<DiscoveryFeedItem> toggleSave(DiscoveryFeedItem item) async {
    final type = item.newsPostId != null
        ? SavedContentType.newsPost
        : SavedContentType.vueMedia;
    final contentId = item.newsPostId ?? item.mediaId;
    final saved = await SavedItemsService.toggleSave(
      contentType: type,
      contentId: contentId,
      currentlySaved: item.userHasSaved,
    );
    return item.copyWith(
      userHasSaved: saved,
      savesCount: (item.savesCount + (saved ? 1 : -1)).clamp(0, 1 << 30),
    );
  }
}
