import 'package:supabase_flutter/supabase_flutter.dart';

/// Records visible-only post impressions via `record_post_impression`.
///
/// Duplicate rapid calls for the same post + feed source are debounced
/// in-memory so scroll flurries do not spam the backend.
class PostImpressionsService {
  PostImpressionsService._();

  static final _client = Supabase.instance.client;

  /// Minimum gap between recordings for the same post + feed_source.
  static const Duration debounceWindow = Duration(seconds: 8);

  static final Map<String, DateTime> _lastRecordedAt = <String, DateTime>{};

  static String _key(String postId, String feedSource) =>
      '$postId::${feedSource.trim().isEmpty ? 'main' : feedSource}';

  /// Clears in-memory debounce state (useful in tests).
  static void clearDebounceCache() => _lastRecordedAt.clear();

  /// Records that [postId] was visible in [feedSource].
  ///
  /// Returns `true` when an RPC was issued, `false` when skipped (unsigned-in,
  /// empty id, or within the debounce window).
  static Future<bool> recordVisibleImpression({
    required String postId,
    String feedSource = 'main',
    int viewDurationMs = 0,
  }) async {
    final me = _client.auth.currentUser;
    if (me == null) return false;

    final id = postId.trim();
    if (id.isEmpty) return false;

    final source = feedSource.trim().isEmpty ? 'main' : feedSource.trim();
    final key = _key(id, source);
    final now = DateTime.now();
    final last = _lastRecordedAt[key];
    if (last != null && now.difference(last) < debounceWindow) {
      return false;
    }

    // Optimistic debounce so concurrent callers for the same key coalesce.
    _lastRecordedAt[key] = now;

    try {
      await _client.rpc(
        'record_post_impression',
        params: {
          'p_post_id': id,
          'p_feed_source': source,
          'p_view_duration_ms': viewDurationMs < 0 ? 0 : viewDurationMs,
        },
      );
      return true;
    } catch (_) {
      // Allow a retry soon if the RPC failed.
      _lastRecordedAt.remove(key);
      return false;
    }
  }
}
