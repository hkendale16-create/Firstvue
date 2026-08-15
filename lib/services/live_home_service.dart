import 'package:supabase_flutter/supabase_flutter.dart';

import 'discovery_feed_service.dart';
import 'things_to_do_service.dart';
import 'user_preferences_service.dart';

enum LiveRightNowKind { event, business }

enum LiveLifecycleStatus {
  upcoming,
  startingSoon,
  live,
  endingSoon,
  ended,
}

class LiveRightNowItem {
  final String id;
  final LiveRightNowKind kind;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final LiveLifecycleStatus lifecycle;
  final int? goingCount;
  final String? locationLabel;
  final CommunityEvent? event;

  const LiveRightNowItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.lifecycle,
    this.goingCount,
    this.locationLabel,
    this.event,
  });

  bool get isLive =>
      lifecycle == LiveLifecycleStatus.live ||
      lifecycle == LiveLifecycleStatus.endingSoon;
}

class LiveHomeSnapshot {
  final String rightNowTitle;
  final String? cityName;
  final List<LiveRightNowItem> rightNow;
  final List<DiscoveryFeedItem> vueItems;
  final String? foodTruckGapNote;

  const LiveHomeSnapshot({
    required this.rightNowTitle,
    required this.cityName,
    required this.rightNow,
    required this.vueItems,
    this.foodTruckGapNote,
  });
}

class LiveHomeService {
  LiveHomeService._();

  static final _client = Supabase.instance.client;

  /// City heading for Right Now. Never hardcodes Atlanta permanently.
  static String rightNowHeading(String? cityName) {
    final city = cityName?.trim() ?? '';
    if (city.isEmpty || city.toLowerCase() == 'everywhere') {
      return '🔥 HAPPENING NOW';
    }
    return '🔥 ${city.toUpperCase()} RIGHT NOW';
  }

  /// Lifecycle from start time only until ends_at is modeled in app (Phase 5).
  static LiveLifecycleStatus lifecycleFor(
    DateTime? eventAt, {
    DateTime? now,
  }) {
    if (eventAt == null) return LiveLifecycleStatus.upcoming;
    final n = now ?? DateTime.now();
    final minutesUntil = eventAt.difference(n).inMinutes;
    if (minutesUntil > 60) return LiveLifecycleStatus.upcoming;
    if (minutesUntil > 0) return LiveLifecycleStatus.startingSoon;
    // Without ends_at, treat the first 6 hours after start as LIVE.
    if (minutesUntil > -6 * 60) return LiveLifecycleStatus.live;
    return LiveLifecycleStatus.ended;
  }

  static String lifecycleLabel(LiveLifecycleStatus status) {
    return switch (status) {
      LiveLifecycleStatus.upcoming => 'UPCOMING',
      LiveLifecycleStatus.startingSoon => 'STARTING SOON',
      LiveLifecycleStatus.live => 'LIVE',
      LiveLifecycleStatus.endingSoon => 'ENDING SOON',
      LiveLifecycleStatus.ended => 'ENDED',
    };
  }

  static Future<LiveHomeSnapshot> load({
    int rightNowLimit = 12,
    int vueLimit = 8,
  }) async {
    final prefs = await UserPreferencesService.fetch();
    final city = prefs.browseEverywhere ? null : prefs.locationCity;
    final heading = rightNowHeading(city);

    final events = await ThingsToDoService.fetchApprovedEvents();
    // Never surface prototype fallback events as LIVE social proof.
    final realEvents =
        events.where((e) => !e.id.startsWith('proto-')).toList();
    final filtered = _filterEventsForCity(realEvents, prefs);
    final ranked = _rankForRightNow(filtered).take(rightNowLimit).toList();

    final goingCounts = await _fetchGoingCounts(
      ranked.map((e) => e.id).toList(),
    );

    final rightNow = <LiveRightNowItem>[];
    for (final event in ranked) {
      final lifecycle = lifecycleFor(event.eventAt);
      if (lifecycle == LiveLifecycleStatus.ended) continue;
      rightNow.add(
        LiveRightNowItem(
          id: event.id,
          kind: LiveRightNowKind.event,
          title: event.title,
          subtitle: event.locationLabel,
          imageUrl: event.coverImageUrl,
          lifecycle: lifecycle,
          goingCount: goingCounts[event.id],
          locationLabel: event.locationLabel,
          event: event,
        ),
      );
    }

    List<DiscoveryFeedItem> vueItems = const [];
    try {
      vueItems = await DiscoveryFeedService.fetchFeed(
        limit: vueLimit,
        mode: VueFeedMode.nearby,
      );
    } catch (_) {
      try {
        vueItems = await DiscoveryFeedService.fetchFeed(
          limit: vueLimit,
          mode: VueFeedMode.forYou,
        );
      } catch (_) {
        vueItems = const [];
      }
    }

    return LiveHomeSnapshot(
      rightNowTitle: heading,
      cityName: city,
      rightNow: rightNow,
      vueItems: vueItems,
      foodTruckGapNote:
          'Food Truck LIVE stops are not in the backend yet — no fabricated truck counts.',
    );
  }

  static List<CommunityEvent> _filterEventsForCity(
    List<CommunityEvent> events,
    UserPreferences prefs,
  ) {
    if (prefs.browseEverywhere) return events;
    final city = prefs.locationCity?.trim().toLowerCase();
    if (city == null || city.isEmpty) return events;
    final matched = events.where((e) {
      final label = (e.locationLabel ?? '').toLowerCase();
      return label.contains(city);
    }).toList();
    // If city filter yields nothing, fall back to all approved (honest empty
    // Right Now is worse than showing real nearby-unscoped events). Prefer
    // real activity over a blank carousel when early-access data is sparse.
    return matched.isNotEmpty ? matched : events;
  }

  static List<CommunityEvent> _rankForRightNow(List<CommunityEvent> events) {
    final now = DateTime.now();
    int score(CommunityEvent e) {
      final status = lifecycleFor(e.eventAt, now: now);
      return switch (status) {
        LiveLifecycleStatus.live => 400,
        LiveLifecycleStatus.endingSoon => 350,
        LiveLifecycleStatus.startingSoon => 300,
        LiveLifecycleStatus.upcoming => 200,
        LiveLifecycleStatus.ended => 0,
      };
    }

    final copy = [...events];
    copy.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      final aAt = a.eventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.eventAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aAt.compareTo(bAt);
    });
    return copy;
  }

  static Future<Map<String, int>> _fetchGoingCounts(List<String> eventIds) async {
    if (eventIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('event_attendance')
          .select('event_id')
          .eq('status', 'attending')
          .inFilter('event_id', eventIds);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['event_id'] as String?;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return const {};
    }
  }

}
