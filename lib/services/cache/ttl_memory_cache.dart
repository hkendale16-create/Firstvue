import 'dart:async';

/// In-memory TTL cache with optional LRU eviction and stale-while-revalidate.
class TtlMemoryCache<V> {
  TtlMemoryCache({
    required this.ttl,
    this.maxEntries = 256,
    this.name = 'cache',
  });

  final Duration ttl;
  final int maxEntries;
  final String name;

  final Map<String, _Entry<V>> _entries = {};
  final List<String> _lru = [];

  int get length => _entries.length;

  V? peek(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    _touch(key);
    return entry.value;
  }

  /// Fresh hit only (within [ttl]).
  V? getFresh(String key, {DateTime? now}) {
    final entry = _entries[key];
    if (entry == null) return null;
    final at = now ?? DateTime.now();
    if (at.difference(entry.at) > ttl) return null;
    _touch(key);
    return entry.value;
  }

  /// Returns value even if stale; [isStale] reports whether revalidation is due.
  ({V value, bool isStale})? getWithStale(String key, {DateTime? now}) {
    final entry = _entries[key];
    if (entry == null) return null;
    final at = now ?? DateTime.now();
    _touch(key);
    return (
      value: entry.value,
      isStale: at.difference(entry.at) > ttl,
    );
  }

  void put(String key, V value, {DateTime? now}) {
    _entries[key] = _Entry(value: value, at: now ?? DateTime.now());
    _touch(key);
    _evictIfNeeded();
  }

  void invalidate(String key) {
    _entries.remove(key);
    _lru.remove(key);
  }

  void clear() {
    _entries.clear();
    _lru.clear();
  }

  /// SWR helper: return cached immediately; refresh in background when stale.
  Future<V> getOrFetch(
    String key,
    Future<V> Function() fetcher, {
    void Function(V value)? onUpdate,
    bool force = false,
  }) async {
    if (!force) {
      final hit = getWithStale(key);
      if (hit != null && !hit.isStale) return hit.value;
      if (hit != null && hit.isStale) {
        unawaited(() async {
          try {
            final fresh = await fetcher();
            put(key, fresh);
            onUpdate?.call(fresh);
          } catch (_) {
            // Keep stale on refresh failure.
          }
        }());
        return hit.value;
      }
    }

    final fresh = await fetcher();
    put(key, fresh);
    return fresh;
  }

  void _touch(String key) {
    _lru.remove(key);
    _lru.add(key);
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries && _lru.isNotEmpty) {
      final oldest = _lru.removeAt(0);
      _entries.remove(oldest);
    }
  }
}

class _Entry<V> {
  final V value;
  final DateTime at;

  const _Entry({required this.value, required this.at});
}
