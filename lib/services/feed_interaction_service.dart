import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/feed_ranking_config.dart';

/// Records source-aware feed interactions via `record_feed_interaction`.
///
/// Impression dedupe is handled by [PostImpressionsService]; this service
/// avoids duplicate rapid identical events with a short in-memory debounce.
class FeedInteractionService {
  FeedInteractionService._();

  static final _client = Supabase.instance.client;
  static const _debounce = Duration(seconds: 4);
  static final Map<String, DateTime> _lastAt = {};
  static String? _sessionId;

  static String get sessionId {
    _sessionId ??=
        'fv-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    return _sessionId!;
  }

  static void clearDebounceCache() => _lastAt.clear();

  static String normalizeSource(String? source) {
    final s = (source ?? FeedRankingConfig.sourceMain).trim();
    const allowed = {
      FeedRankingConfig.sourceMain,
      FeedRankingConfig.sourceCommunities,
      FeedRankingConfig.sourceGroups,
      FeedRankingConfig.sourceTrending,
      FeedRankingConfig.sourceNew,
      FeedRankingConfig.sourceRecommended,
      'profile',
      'vue',
      'other',
    };
    return allowed.contains(s) ? s : 'other';
  }

  static Future<bool> record({
    required String postId,
    required String interactionType,
    String sourceTab = FeedRankingConfig.sourceMain,
    int watchTimeMs = 0,
    double? completionPercent,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) return false;
    final id = postId.trim();
    if (id.isEmpty) return false;

    final source = normalizeSource(sourceTab);
    final key = '$id::$interactionType::$source';
    final now = DateTime.now();
    final last = _lastAt[key];
    if (last != null && now.difference(last) < _debounce) {
      return false;
    }
    _lastAt[key] = now;

    try {
      await _client.rpc(
        'record_feed_interaction',
        params: {
          'p_post_id': id,
          'p_interaction_type': interactionType,
          'p_source_tab': source,
          'p_watch_time_ms': watchTimeMs < 0 ? 0 : watchTimeMs,
          'p_completion_percent': completionPercent,
          'p_session_id': sessionId,
        },
      );
      return true;
    } catch (_) {
      _lastAt.remove(key);
      return false;
    }
  }
}
