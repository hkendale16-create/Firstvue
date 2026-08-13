import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/discovery_feed_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/social_chrome.dart';
import 'business_profile_screen.dart';
import 'create_post_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'member_public_profile_screen.dart';

enum _FeedMode { forYou, nearby, trending }

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late Future<List<DiscoveryFeedItem>> _feedFuture;
  List<_FeedItem> _feedItems = const [];
  _FeedMode _mode = _FeedMode.forYou;

  static const _items = [
    _FeedItem(
      'Marcus Reed',
      'Fresh skin fade in Midtown',
      'Fades • Beard work • Designs',
      '1.2 mi',
      4.9,
      328,
      'assets/images/explore_barbers.jpg',
      Icons.content_cut,
      true,
      false,
    ),
    _FeedItem(
      'Velvet Room Salon',
      'Silk press with movement and shine',
      'Silk press • Color • Natural hair',
      '1.6 mi',
      4.9,
      186,
      'assets/images/explore_salons.jpg',
      Icons.chair_alt_rounded,
      true,
      true,
    ),
    _FeedItem(
      'Lumen Beauty Studio',
      'A quick brow transformation',
      'Skin • Brows • Makeup',
      '1.8 mi',
      4.8,
      224,
      'assets/images/explore_beauty.jpg',
      Icons.auto_awesome,
      false,
      false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _feedFuture = _loadFeed();
  }

  Future<List<DiscoveryFeedItem>> _loadFeed() async {
    final mode = switch (_mode) {
      _FeedMode.forYou => VueFeedMode.forYou,
      _FeedMode.nearby => VueFeedMode.nearby,
      _FeedMode.trending => VueFeedMode.trending,
    };
    final items = await DiscoveryFeedService.fetchFeed(mode: mode);
    if (!mounted) return items;
    final mapped = _connectedItems(items);
    setState(() {
      _feedItems = mapped.isEmpty ? _items : mapped;
    });
    return items;
  }

  Future<void> _refreshFeed() async {
    await _loadFeed();
  }

  void _openProfile(_FeedItem item) {
    final connected = item.connected;
    if (connected != null && connected.isMember) {
      DiscoveryFeedService.recordProfileTap(connected);
      openMemberProfile(
        context,
        profileId: connected.ownerId,
        displayName: connected.ownerName,
      );
      return;
    }
    if (connected != null && connected.businessId.isNotEmpty) {
      DiscoveryFeedService.recordProfileTap(connected);
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) =>
              FirstVueBusinessProfileScreen(businessId: connected.businessId),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => BusinessProfileScreen(
          businessName: item.name,
          rating: item.rating,
          reviews: item.reviews,
          verified: item.verified,
          distance: item.distance,
          specialty: item.specialty,
          profileIcon: item.icon,
          profileLabel: 'Discovered on Vue Feed',
          aboutText:
              'See services, pricing, reviews, photos, availability, and booking details from this business.',
        ),
      ),
    );
  }

  List<_FeedItem> _connectedItems(List<DiscoveryFeedItem> items) => items
      .map(
        (item) => _FeedItem(
          item.businessName,
          item.isMember
              ? '${item.caption} • @${item.ownerName}'
              : '${item.caption} • @${item.ownerName}',
          item.services.isEmpty ? item.businessType : item.services.join(' • '),
          item.isMember ? 'Member' : 'Nearby',
          item.rating,
          0,
          item.mediaUrl,
          item.isMember ? Icons.person_rounded : Icons.storefront_rounded,
          item.verified,
          item.sponsored,
          connected: item,
          mediaType: item.mediaType,
        ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return ColoredBox(
      color: fv.background,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SocialPageHeader(
                    title: 'VUE',
                    subtitle: 'Watch, follow, and book local talent.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: SocialPillTabs(
                    labels: const ['For You', 'Nearby', 'Trending'],
                    selectedIndex: _mode.index,
                    onSelected: (index) {
                      final next = _FeedMode.values[index];
                      if (next == _mode) return;
                      setState(() => _mode = next);
                      _feedFuture = _loadFeed();
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SocialSearchBar(),
                ),
                Expanded(
                  child: FutureBuilder<List<DiscoveryFeedItem>>(
                    future: _feedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: FirstVueColors.gold,
                          ),
                        );
                      }
                      final items = _feedItems.isEmpty ? _items : _feedItems;
                      return FirstVueRefreshScaffold(
                        onRefresh: _refreshFeed,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, index) {
                            final item = items[index];
                            return SocialPostTile(
                              handle: socialHandleFromName(item.name),
                              avatarUrl: item.connected?.mediaUrl,
                              imageUrl:
                                  item.connected != null ? item.image : null,
                              assetImage:
                                  item.connected == null ? item.image : null,
                              likeLabel: item.reviews > 0
                                  ? '${item.reviews}'
                                  : index.isEven
                                      ? '2.1k'
                                      : '843',
                              showPlay: true,
                              durationLabel: item.mediaType == 'video' ||
                                      item.connected == null
                                  ? '0:12'
                                  : null,
                              live: item.sponsored,
                              showOutlineFollow: true,
                              showMenu: false,
                              onFollow: () => _openProfile(item),
                              onTap: () => _openProfile(item),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 48,
              right: 48,
              bottom: 16,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(
                      builder: (_) => const CreatePostScreen(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  '+ Create a Vue',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedItem {
  final String name, caption, specialty, distance, image;
  final double rating;
  final int reviews;
  final IconData icon;
  final bool verified, sponsored;
  final DiscoveryFeedItem? connected;
  final String? mediaType;
  const _FeedItem(
    this.name,
    this.caption,
    this.specialty,
    this.distance,
    this.rating,
    this.reviews,
    this.image,
    this.icon,
    this.verified,
    this.sponsored, {
    this.connected,
    this.mediaType,
  });
}
