import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:firstvue/services/cache/ttl_memory_cache.dart';

void main() {
  test('TtlMemoryCache returns fresh hits and expires after ttl', () {
    final cache = TtlMemoryCache<String>(
      ttl: const Duration(milliseconds: 50),
      maxEntries: 4,
    );
    final t0 = DateTime.utc(2026, 1, 1, 12);
    cache.put('a', 'alpha', now: t0);
    expect(cache.getFresh('a', now: t0), 'alpha');
    expect(
      cache.getFresh('a', now: t0.add(const Duration(milliseconds: 60))),
      isNull,
    );
    final stale = cache.getWithStale(
      'a',
      now: t0.add(const Duration(milliseconds: 60)),
    );
    expect(stale?.value, 'alpha');
    expect(stale?.isStale, isTrue);
  });

  test('TtlMemoryCache evicts least-recently-used entries', () {
    final cache = TtlMemoryCache<int>(
      ttl: const Duration(minutes: 5),
      maxEntries: 2,
    );
    cache.put('a', 1);
    cache.put('b', 2);
    cache.peek('a'); // touch a so b is older
    cache.put('c', 3);
    expect(cache.peek('b'), isNull);
    expect(cache.peek('a'), 1);
    expect(cache.peek('c'), 3);
  });

  test('getOrFetch serves stale while refreshing', () async {
    final cache = TtlMemoryCache<int>(
      ttl: const Duration(milliseconds: 20),
      maxEntries: 4,
    );
    final t0 = DateTime.utc(2026, 1, 1);
    cache.put('n', 1, now: t0);
    var fetches = 0;
    final completer = Completer<void>();
    final value = await cache.getOrFetch(
      'n',
      () async {
        fetches++;
        return 2;
      },
      onUpdate: (_) => completer.complete(),
    );
    // Stale value returned immediately.
    expect(value, 1);
    await completer.future.timeout(const Duration(seconds: 2));
    expect(fetches, 1);
    expect(cache.getFresh('n'), 2);
  });
}
