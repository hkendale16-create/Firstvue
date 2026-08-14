import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../services/discovery_feed_service.dart';
import '../services/business_follow_service.dart';
import '../services/follow_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/social_chrome.dart';
import 'auth_screen.dart';
import 'business_profile_screen.dart';
import 'create_post_screen.dart';
import 'firstvue_business_profile_screen.dart';
import 'full_screen_media_viewer.dart';
import 'member_public_profile_screen.dart';
import 'post_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String? _error;

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
    try {
      final items = await DiscoveryFeedService.fetchFeed(
        mode: mode,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return items;
      setState(() {
        _feedItems = _connectedItems(items);
        _error = null;
      });
      return items;
    } catch (error) {
      if (!mounted) return const [];
      setState(() {
        _feedItems = const [];
        _error = 'Unable to load VUE right now.';
      });
      rethrow;
    }
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _error = null;
      _feedFuture = _loadFeed();
    });
    try {
      await _feedFuture;
    } catch (_) {}
  }

  void _openMedia(_FeedItem item) {
    final connected = item.connected;
    if (connected?.newsPostId != null) {
      Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => PostDetailScreen(postId: connected!.newsPostId!),
        ),
      );
      return;
    }
    if (item.image.startsWith('http')) {
      if (item.mediaType == 'video') {
        openFullScreenVideoPlayer(context, url: item.image, title: item.name);
      } else {
        openFullScreenImageViewer(
          context,
          items: [
            FullScreenMediaItem(
              url: item.image,
              isVideo: false,
              caption: item.caption,
            ),
          ],
          title: item.name,
        );
      }
      return;
    }
    _openProfile(item);
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

  Future<void> _toggleFollow(_FeedItem item) async {
    final connected = item.connected;
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (Supabase.instance.client.auth.currentUser == null) return;
    }
    try {
      if (connected != null && connected.isMember) {
        final status = await FollowService.followStatus(connected.ownerId);
        if (status == FollowStatus.following ||
            status == FollowStatus.pending) {
          await FollowService.unfollow(connected.ownerId);
        } else {
          await FollowService.follow(connected.ownerId);
        }
      } else if (connected != null && connected.businessId.isNotEmpty) {
        final following = await BusinessFollowService.isFollowing(
          connected.businessId,
        );
        await BusinessFollowService.toggle(
          connected.businessId,
          currentlyFollowing: following,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open the profile to follow.')),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follow updated')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not update follow.')));
    }
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
                  child: SocialSearchBar(iconOnly: true),
                ),
                Expanded(
                  child: FutureBuilder<List<DiscoveryFeedItem>>(
                    future: _feedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          _feedItems.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: FirstVueColors.gold,
                          ),
                        );
                      }
                      if (snapshot.hasError || _error != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error ?? 'Unable to load VUE right now.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: fv.secondaryText),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _error = null;
                                      _feedFuture = _loadFeed();
                                    });
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      if (_feedItems.isEmpty) {
                        return Center(
                          child: Text(
                            'No photos or videos to show yet.',
                            style: TextStyle(color: fv.secondaryText),
                          ),
                        );
                      }
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
                          itemCount: _feedItems.length,
                          itemBuilder: (_, index) {
                            final item = _feedItems[index];
                            final isVideo = item.mediaType == 'video';
                            return SocialPostTile(
                              handle: socialHandleFromName(item.name),
                              avatarUrl: item.connected?.mediaUrl,
                              imageUrl: item.image.startsWith('http')
                                  ? item.image
                                  : null,
                              assetImage: item.image.startsWith('http')
                                  ? null
                                  : item.image,
                              likeLabel: item.reviews > 0
                                  ? '${item.reviews}'
                                  : null,
                              showPlay: isVideo,
                              durationLabel: isVideo ? '0:03' : null,
                              live: item.sponsored,
                              showOutlineFollow: true,
                              showMenu: false,
                              onFollow: () => _toggleFollow(item),
                              onTap: () => _openMedia(item),
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
                    FirstVuePageRoute(builder: (_) => const CreatePostScreen()),
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
