import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_news_service.dart';
import '../services/recommendations_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/social_chrome.dart';
import 'barber_results_screen.dart';
import 'beauty_discovery_screen.dart';
import 'discovery_feed_screen.dart';
import 'other_services_screen.dart';
import 'people_to_follow_screen.dart';
import 'post_detail_screen.dart';
import 'rentals_screen.dart';
import 'things_to_do_screen.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback? onOpenVueFeed;

  const ExploreScreen({super.key, this.onOpenVueFeed});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<List<_ExploreTile>> _tilesFuture;

  @override
  void initState() {
    super.initState();
    _tilesFuture = _loadTiles();
  }

  Future<List<_ExploreTile>> _loadTiles() async {
    try {
      final posts = await CommunityNewsService.fetchPosts(limit: 24);
      final fromPosts = posts
          .where((post) => post.media.isNotEmpty)
          .map(
            (post) => _ExploreTile(
              handle: socialHandleFromName(
                post.authorUsername ?? post.authorName,
              ),
              imageUrl: post.media.first.signedUrl,
              avatarUrl: post.communityImageUrl,
              likeLabel: post.sparkCount > 0 ? _formatCount(post.sparkCount) : null,
              isVideo: post.media.first.isVideo,
              onTap: () {
                Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => PostDetailScreen(postId: post.id),
                  ),
                );
              },
            ),
          )
          .toList();
      if (fromPosts.length >= 4) return fromPosts;
      return [...fromPosts, ..._fallbackTiles(context)];
    } catch (_) {
      return _fallbackTiles(context);
    }
  }

  static String _formatCount(int count) {
    if (count >= 1000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$count';
  }

  List<_ExploreTile> _fallbackTiles(BuildContext context) {
    final categories = _categories(context);
    const likes = ['2.1k', '1.7k', '843', '2.4k', null, '612'];
    return [
      for (var i = 0; i < categories.length; i++)
        _ExploreTile(
          handle: socialHandleFromName(categories[i].handle),
          assetImage: categories[i].imagePath,
          likeLabel: i < likes.length ? likes[i] : null,
          showFollowOverlay: i == 1,
          dateLabel: i == 4 ? 'MAY 24' : null,
          onTap: categories[i].onTap,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: () async {
          final next = _loadTiles();
          setState(() => _tilesFuture = next);
          await next;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const SocialPageHeader(
              title: 'EXPLORE',
              subtitle:
                  'Discover local pros, follow their work, book with confidence.',
            ),
            const SizedBox(height: 16),
            const SocialSearchBar(),
            const SizedBox(height: 20),
            PeopleToFollowRow(
              onSeeAll: () {
                Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => const PeopleToFollowScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            FutureBuilder<List<_ExploreTile>>(
              future: _tilesFuture,
              builder: (context, snapshot) {
                final tiles = snapshot.data ?? _fallbackTiles(context);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: tiles.length,
                  itemBuilder: (context, index) {
                    final tile = tiles[index];
                    return SocialPostTile(
                      handle: tile.handle,
                      avatarUrl: tile.avatarUrl,
                      imageUrl: tile.imageUrl,
                      assetImage: tile.assetImage,
                      likeLabel: tile.likeLabel,
                      dateLabel: tile.dateLabel,
                      showPlay: tile.isVideo,
                      showFollowOverlay: tile.showFollowOverlay,
                      onTap: tile.onTap,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 18),
            _VueFeedBanner(onTap: widget.onOpenVueFeed),
          ],
        ),
      ),
    );
  }

  static List<_ExploreCategory> _categories(BuildContext context) {
    return [
      _ExploreCategory(
        handle: 'marcusreedcuts',
        imagePath: 'assets/images/explore_beauty.jpg',
        onTap: () {
          RecommendationsService.recordCategoryVisit('beauty');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const BeautyDiscoveryScreen()),
          );
        },
      ),
      _ExploreCategory(
        handle: 'velvetroomsalon',
        imagePath: 'assets/images/explore_restaurants.jpg',
        onTap: () {
          RecommendationsService.recordCategoryVisit('restaurant');
          Navigator.push(
            context,
            FirstVuePageRoute(
              builder: (_) => const BarberResultsScreen(
                category: DiscoveryCategory.restaurants,
              ),
            ),
          );
        },
      ),
      _ExploreCategory(
        handle: 'glowtheorystudio',
        imagePath: 'assets/images/explore_rentals.jpg',
        onTap: () {
          RecommendationsService.recordCategoryVisit('rentals');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const RentalsScreen()),
          );
        },
      ),
      _ExploreCategory(
        handle: 'table45atl',
        imagePath: 'assets/images/explore_things_to_do.jpg',
        onTap: () {
          RecommendationsService.recordCategoryVisit('events');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const ThingsToDoScreen()),
          );
        },
      ),
      _ExploreCategory(
        handle: 'atlparkfest',
        imagePath: 'assets/images/explore_barbershops.jpg',
        onTap: () {
          RecommendationsService.recordCategoryVisit('services');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const OtherServicesScreen()),
          );
        },
      ),
      _ExploreCategory(
        handle: 'stayvueatl',
        imagePath: 'assets/images/explore_salons.jpg',
        onTap: () {
          RecommendationsService.recordCategoryVisit('beauty');
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const BeautyDiscoveryScreen()),
          );
        },
      ),
    ];
  }
}

class _ExploreTile {
  final String handle;
  final String? imageUrl;
  final String? assetImage;
  final String? avatarUrl;
  final String? likeLabel;
  final String? dateLabel;
  final bool isVideo;
  final bool showFollowOverlay;
  final VoidCallback onTap;

  const _ExploreTile({
    required this.handle,
    required this.onTap,
    this.imageUrl,
    this.assetImage,
    this.avatarUrl,
    this.likeLabel,
    this.dateLabel,
    this.isVideo = false,
    this.showFollowOverlay = false,
  });
}

class _ExploreCategory {
  final String handle;
  final String imagePath;
  final VoidCallback onTap;

  const _ExploreCategory({
    required this.handle,
    required this.imagePath,
    required this.onTap,
  });
}

class _VueFeedBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const _VueFeedBanner({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
            return;
          }
          Navigator.push(
            context,
            FirstVuePageRoute(builder: (_) => const DiscoveryFeedScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: FirstVueColors.teal,
          ),
          child: const Row(
            children: [
              Icon(Icons.open_in_full_rounded, color: Colors.white, size: 22),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Open Vue — full-screen social feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
