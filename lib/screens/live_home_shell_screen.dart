import 'dart:async';

import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/full_screen_media_viewer.dart';
import '../screens/member_public_profile_screen.dart';
import '../screens/people_to_follow_screen.dart';
import '../screens/post_detail_screen.dart';
import '../services/discovery_feed_service.dart';
import '../services/live_home_service.dart';
import '../services/live_realtime_service.dart';
import '../theme/firstvue_theme.dart';
import '../theme/live_tokens.dart';
import '../screens/live_event_detail_screen.dart';
import '../screens/live_map_screen.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/live/live_category_row.dart';
import '../widgets/live/live_right_now_card.dart';
import '../widgets/live/live_vue_feed_strip.dart';

/// LIVE Home — Right Now + Explore Live Map + VUE strip.
class LiveHomeShellScreen extends StatefulWidget {
  final VoidCallback? onReturnToVue;

  /// When set (tests), skips network load.
  final LiveHomeSnapshot? initialSnapshot;

  const LiveHomeShellScreen({
    super.key,
    this.onReturnToVue,
    this.initialSnapshot,
  });

  @override
  State<LiveHomeShellScreen> createState() => _LiveHomeShellScreenState();
}

class _LiveHomeShellScreenState extends State<LiveHomeShellScreen> {
  late Future<LiveHomeSnapshot> _future;
  LiveDiscoveryCategory _category = LiveDiscoveryCategory.events;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialSnapshot;
    _future = seed != null
        ? Future<LiveHomeSnapshot>.value(seed)
        : LiveHomeService.load();
    if (seed == null) {
      LiveRealtimeService.subscribeHome(onChange: () {
        if (!mounted) return;
        unawaited(_reload());
      });
    }
  }

  @override
  void dispose() {
    LiveRealtimeService.unsubscribeHome();
    super.dispose();
  }

  Future<void> _reload() async {
    final next = LiveHomeService.load();
    setState(() => _future = next);
    await next;
  }

  void _onCategory(LiveDiscoveryCategory category) {
    setState(() => _category = category);
    if (category == LiveDiscoveryCategory.people) {
      Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const PeopleToFollowScreen()),
      );
    }
  }

  Future<void> _openEvent(LiveRightNowItem item) async {
    if (item.kind == LiveRightNowKind.business &&
        item.businessId != null &&
        item.businessId!.isNotEmpty) {
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

  void _openMap() {
    if (!FeatureFlags.liveMapEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Explore Live Map is turned off in this build.'),
        ),
      );
      return;
    }
    LiveMapScreen.open(context);
  }

  void _openVue(DiscoveryFeedItem item) {
    if (item.newsPostId != null) {
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => PostDetailScreen(postId: item.newsPostId!),
        ),
      );
      return;
    }
    if (item.mediaUrl.startsWith('http')) {
      if (item.isVideo) {
        openFullScreenVideoPlayer(
          context,
          url: item.mediaUrl,
          title: item.businessName,
        );
      } else {
        openFullScreenImageViewer(
          context,
          items: [
            FullScreenMediaItem(url: item.mediaUrl, isVideo: false),
          ],
          title: item.businessName,
        );
      }
      return;
    }
    if (item.isMember) {
      openMemberProfile(
        context,
        profileId: item.ownerId,
        displayName: item.ownerName,
      );
      return;
    }
    if (item.businessId.isNotEmpty) {
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: item.businessId),
        ),
      );
    }
  }

  List<LiveRightNowItem> _visibleRightNow(LiveHomeSnapshot snap) {
    if (_category == LiveDiscoveryCategory.food ||
        _category == LiveDiscoveryCategory.businesses) {
      if (!FeatureFlags.liveFoodTrucksEnabled) return const [];
      if (_category == LiveDiscoveryCategory.food) {
        return snap.openBusinesses
            .where((i) {
              final sub = (i.subtitle ?? '').toLowerCase();
              return sub.contains('food') || sub.contains('truck');
            })
            .toList();
      }
      return snap.openBusinesses;
    }
    if (_category == LiveDiscoveryCategory.nightlife) {
      return snap.rightNow.where((i) {
        if (i.kind != LiveRightNowKind.event) return false;
        final t = i.title.toLowerCase();
        final l = (i.locationLabel ?? '').toLowerCase();
        return t.contains('night') ||
            t.contains('club') ||
            t.contains('bar') ||
            l.contains('night');
      }).toList();
    }
    // Events (default): event cards + live open businesses mixed in snapshot.
    return snap.rightNow
        .where(
          (i) =>
              i.kind == LiveRightNowKind.event ||
              (FeatureFlags.liveFoodTrucksEnabled &&
                  i.kind == LiveRightNowKind.business &&
                  i.isLive),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return ColoredBox(
      color: fv.background,
      child: FutureBuilder<LiveHomeSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;
          final data = snapshot.data;

          return FirstVueRefreshScaffold(
            onRefresh: _reload,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          'FirstVue',
                          style: TextStyle(
                            fontFamily: 'CormorantGaramond',
                            color: LiveTokens.bronzeSoft,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        if (widget.onReturnToVue != null)
                          TextButton(
                            onPressed: widget.onReturnToVue,
                            style: TextButton.styleFrom(
                              foregroundColor: fv.secondaryText,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('VUE'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: LiveCategoryRow(
                    selected: _category,
                    onSelected: _onCategory,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      data?.rightNowTitle ?? '🔥 HAPPENING NOW',
                      style: TextStyle(
                        color: fv.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                if (loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: LiveTokens.bronze,
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _RightNowSection(
                      items: data == null
                          ? const []
                          : _visibleRightNow(data),
                      category: _category,
                      onOpen: _openEvent,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: OutlinedButton(
                        onPressed: _openMap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LiveTokens.bronzeSoft,
                          side: const BorderSide(color: LiveTokens.bronze),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '🗺️  Explore Live Map  >',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Text(
                        'VUE FEED',
                        style: TextStyle(
                          color: fv.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: LiveVueFeedStrip(
                      items: data?.vueItems ?? const [],
                      onOpen: _openVue,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RightNowSection extends StatelessWidget {
  final List<LiveRightNowItem> items;
  final LiveDiscoveryCategory category;
  final ValueChanged<LiveRightNowItem> onOpen;

  const _RightNowSection({
    required this.items,
    required this.category,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (category == LiveDiscoveryCategory.food ||
        category == LiveDiscoveryCategory.businesses) {
      if (items.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _EmptyCard(
            title: 'No LIVE ${category.label.toLowerCase()} yet',
            body: FeatureFlags.liveFoodTrucksEnabled
                ? 'Open locations appear here when operators check in nearby.'
                : 'Food Truck / business LIVE check-ins are turned off in this build.',
          ),
        );
      }
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: _EmptyCard(
          title: 'It’s quiet here right now',
          body:
              'Explore nearby areas later, or switch categories. '
              'Upcoming events will appear when they are live.',
        ),
      );
    }

    return SizedBox(
      height: LiveTokens.cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 220 + (index * 40).clamp(0, 200)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: LiveRightNowCard(
              item: item,
              onTap: () => onOpen(item),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String body;

  const _EmptyCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: LiveTokens.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fv.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: fv.primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: fv.secondaryText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
