import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../models/growth_prompt.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/live_event_detail_screen.dart';
import '../screens/people_to_follow_screen.dart';
import '../services/event_time_windows.dart';
import '../services/growth_prompt_catalog.dart';
import '../services/live_home_service.dart';
import '../services/things_to_do_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';
import 'growth_prompt.dart';
import 'live/live_right_now_card.dart';
import 'social_chrome.dart';

/// Home hero: LIVE nearby, tonight, this weekend, then follow seeds.
class WhatsOnNearYou extends StatefulWidget {
  final int refreshToken;
  final VoidCallback? onSetCity;

  const WhatsOnNearYou({
    super.key,
    this.refreshToken = 0,
    this.onSetCity,
  });

  @override
  State<WhatsOnNearYou> createState() => _WhatsOnNearYouState();
}

class _WhatsOnNearYouState extends State<WhatsOnNearYou> {
  late Future<_WhatsOnSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant WhatsOnNearYou oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _future = _load();
    }
  }

  Future<_WhatsOnSnapshot> _load() async {
    try {
      final live = FeatureFlags.liveModeEnabled
          ? await LiveHomeService.load(rightNowLimit: 8, vueLimit: 0)
          : null;
      final events = await ThingsToDoService.fetchApprovedEvents();
      final real = [
        for (final event in events)
          if (!event.id.startsWith('proto-')) event,
      ];
      final liveItems = [
        for (final item in live?.rightNow ?? const <LiveRightNowItem>[])
          if (item.isLive) item,
      ];
      final nowEvents = EventTimeWindows.happeningNow(real);
      final tonight = EventTimeWindows.tonight(real);
      final tonightIds = {for (final event in tonight) event.id};
      final weekend = [
        for (final event in EventTimeWindows.thisWeekend(real))
          if (!tonightIds.contains(event.id)) event,
      ];
      return _WhatsOnSnapshot(
        liveItems: liveItems,
        happeningNow: nowEvents,
        tonight: tonight,
        weekend: weekend,
      );
    } catch (_) {
      return const _WhatsOnSnapshot();
    }
  }

  void _openPeople() {
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const PeopleToFollowScreen()),
    );
  }

  Future<void> _openLive(LiveRightNowItem item) async {
    if (item.kind == LiveRightNowKind.business &&
        (item.businessId ?? '').isNotEmpty) {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: item.businessId!),
        ),
      );
      return;
    }
    final event = item.event;
    if (event == null) return;
    await LiveEventDetailScreen.open(context, event);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WhatsOnSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final waiting =
            snapshot.connectionState == ConnectionState.waiting && data == null;
        if (waiting) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SizedBox(
              height: 72,
              child: Center(
                child: CircularProgressIndicator(color: FirstVueColors.teal),
              ),
            ),
          );
        }
        final pack = data ?? const _WhatsOnSnapshot();
        final shownIds = <String>{
          for (final item in pack.liveItems) item.id,
        };
        if (pack.liveItems.isEmpty) {
          shownIds.addAll(pack.happeningNow.map((e) => e.id));
        }
        final tonight = [
          for (final event in pack.tonight)
            if (!shownIds.contains(event.id)) event,
        ];
        shownIds.addAll(tonight.map((e) => e.id));
        final weekend = [
          for (final event in pack.weekend)
            if (!shownIds.contains(event.id)) event,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pack.liveItems.isNotEmpty) ...[
              const SocialSectionHeader(title: 'LIVE nearby'),
              const SizedBox(height: 10),
              SizedBox(
                height: LiveTokens.cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pack.liveItems.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = pack.liveItems[index];
                    return LiveRightNowCard(
                      item: item,
                      onTap: () => _openLive(item),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ] else if (pack.happeningNow.isNotEmpty) ...[
              const SocialSectionHeader(title: 'Happening now'),
              const SizedBox(height: 10),
              for (final event in pack.happeningNow.take(4)) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
            ],
            if (tonight.isNotEmpty) ...[
              const SocialSectionHeader(title: 'Tonight'),
              const SizedBox(height: 10),
              for (final event in tonight.take(4)) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
            ],
            if (tonight.length < 2 && weekend.isNotEmpty) ...[
              const SocialSectionHeader(title: 'This weekend'),
              const SizedBox(height: 10),
              for (final event in weekend.take(4)) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
            ],
            if (pack.isThin) ...[
              GrowthPrompt(
                spec: GrowthPromptCatalog.specFor(
                  GrowthPromptType.discoverNearby,
                  context: GrowthPromptContext.home,
                ),
                variant: GrowthPromptVariant.empty,
              ),
              if (widget.onSetCity != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onSetCity,
                    child: const Text('Set your city'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
            PeopleToFollowRow(onSeeAll: _openPeople),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _WhatsOnSnapshot {
  final List<LiveRightNowItem> liveItems;
  final List<CommunityEvent> happeningNow;
  final List<CommunityEvent> tonight;
  final List<CommunityEvent> weekend;

  const _WhatsOnSnapshot({
    this.liveItems = const [],
    this.happeningNow = const [],
    this.tonight = const [],
    this.weekend = const [],
  });

  bool get isThin =>
      liveItems.isEmpty &&
      happeningNow.isEmpty &&
      tonight.isEmpty &&
      weekend.isEmpty;
}
