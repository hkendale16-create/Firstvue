import 'package:flutter/material.dart';

import '../constants/business_types.dart';
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

enum _ExploreChip { businesses, people, events, thingsToDo, food, bars }

class ExploreScreen extends StatefulWidget {
  final VoidCallback? onOpenVueFeed;

  const ExploreScreen({super.key, this.onOpenVueFeed});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _pageSize = 24;

  final _scrollController = ScrollController();
  final List<_ExploreTile> _tiles = [];
  final Set<String> _seenIds = {};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  _ExploreChip? _selectedChip;
  String? _filterProfileType;
  String? _filterBusinessType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  bool get _filtersActive =>
      _filterProfileType != null || _filterBusinessType != null;

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 720) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final posts = await _fetchPage();
      if (!mounted) return;
      setState(() {
        _tiles
          ..clear()
          ..addAll(posts.map(_tileFromPost));
        _seenIds
          ..clear()
          ..addAll(posts.map((p) => p.id));
        _loading = false;
        _hasMore = posts.length >= _pageSize;
        if (_tiles.isEmpty) {
          _tiles.addAll(_fallbackTiles(context));
          _hasMore = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load Explore right now.';
        if (_tiles.isEmpty) {
          _tiles.addAll(_fallbackTiles(context));
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _fetchPage(cursorFrom: _lastPostCursor());
      final fresh = <_ExploreTile>[];
      for (final post in more) {
        if (_seenIds.add(post.id)) {
          fresh.add(_tileFromPost(post));
        }
      }
      if (!mounted) return;
      setState(() {
        _tiles.addAll(fresh);
        _hasMore = more.length >= _pageSize;
        _loadingMore = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _error = 'Could not load more. Tap to retry.';
      });
    }
  }

  ({DateTime? createdAt, String? id})? _lastPostCursor() {
    for (var i = _tiles.length - 1; i >= 0; i--) {
      final tile = _tiles[i];
      if (tile.postId != null && tile.createdAt != null) {
        return (createdAt: tile.createdAt, id: tile.postId);
      }
    }
    return null;
  }

  Future<List<CommunityNewsPost>> _fetchPage({
    ({DateTime? createdAt, String? id})? cursorFrom,
  }) {
    final categoryFilters = _filtersForChip(_selectedChip);
    return CommunityNewsService.fetchExplorePosts(
      limit: _pageSize,
      beforeCreatedAt: cursorFrom?.createdAt,
      beforeId: cursorFrom?.id,
      profileType: _filterProfileType ?? categoryFilters.profileType,
      businessType: _filterBusinessType ?? categoryFilters.businessType,
    ).then((posts) {
      if (_selectedChip == null) return posts;
      return posts.where(_matchesChip).toList(growable: false);
    });
  }

  ({String? profileType, String? businessType}) _filtersForChip(
    _ExploreChip? chip,
  ) {
    return switch (chip) {
      _ExploreChip.businesses => (profileType: 'business', businessType: null),
      _ExploreChip.people => (profileType: 'user', businessType: null),
      _ExploreChip.events => (profileType: 'event', businessType: null),
      _ExploreChip.thingsToDo => (profileType: 'activity', businessType: null),
      _ExploreChip.food => (profileType: null, businessType: 'Restaurant'),
      _ExploreChip.bars => (profileType: null, businessType: 'Bar'),
      null => (profileType: null, businessType: null),
    };
  }

  bool _matchesChip(CommunityNewsPost post) {
    final type = post.resolvedAuthorProfileType;
    final businessType = (post.businessType ?? '').toLowerCase();
    final body = post.body.toLowerCase();
    final hasActivitySignal =
        body.contains('#thingstodo') ||
        body.contains('things to do') ||
        businessType.contains('activity') ||
        businessType.contains('attraction') ||
        businessType.contains('recreation') ||
        businessType.contains('entertainment') ||
        businessType.contains('experience');
    return switch (_selectedChip) {
      null => true,
      _ExploreChip.businesses => type == 'business' || post.businessId != null,
      _ExploreChip.people => type == 'user' && post.businessId == null,
      _ExploreChip.events => type == 'event' || post.eventId != null,
      _ExploreChip.thingsToDo =>
        hasActivitySignal ||
            type == 'activity' ||
            (type == 'business' &&
                (businessType.contains('activity') ||
                    businessType.contains('attraction') ||
                    businessType.contains('recreation') ||
                    businessType.contains('entertainment') ||
                    businessType.contains('experience'))),
      _ExploreChip.food =>
        businessType.contains('restaurant') ||
            businessType.contains('food') ||
            businessType.contains('dining') ||
            businessType.contains('cafe') ||
            businessType.contains('café') ||
            businessType.contains('bakery') ||
            businessType.contains('cater') ||
            businessType.contains('bistro') ||
            businessType.contains('truck'),
      _ExploreChip.bars =>
        businessType.contains('bar') ||
            businessType.contains('lounge') ||
            businessType.contains('club') ||
            businessType.contains('brewery') ||
            businessType.contains('nightlife') ||
            businessType.contains('pub'),
    };
  }

  _ExploreTile _tileFromPost(CommunityNewsPost post) {
    final media = post.media.first;
    return _ExploreTile(
      postId: post.id,
      createdAt: post.createdAt,
      handle: socialHandleFromName(post.authorUsername ?? post.authorName),
      imageUrl: media.isVideo ? null : media.signedUrl,
      videoUrl: media.isVideo ? media.signedUrl : null,
      avatarUrl: post.communityImageUrl,
      likeLabel: post.sparkCount > 0 ? _formatCount(post.sparkCount) : null,
      isVideo: media.isVideo,
      onTap: () {
        Navigator.push(
          context,
          FirstVuePageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
        );
      },
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
    }
    return '$count';
  }

  void _selectChip(_ExploreChip chip) {
    setState(() {
      _selectedChip = _selectedChip == chip ? null : chip;
    });
    _reload();
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_ExploreFilterResult>(
      context: context,
      backgroundColor: context.fv.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExploreFilterSheet(
        profileType: _filterProfileType,
        businessType: _filterBusinessType,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filterProfileType = result.profileType;
      _filterBusinessType = result.businessType;
    });
    await _reload();
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
    final fv = context.fv;
    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: _reload,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const SocialPageHeader(
              title: 'EXPLORE',
              subtitle:
                  'Discover local pros, follow their work, book with confidence.',
            ),
            const SizedBox(height: 16),
            SocialSearchBar(
              onFilterTap: _openFilters,
              filterActive: _filtersActive,
            ),
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
            const SizedBox(height: 14),
            _ExploreCategoryHeader(
              selected: _selectedChip,
              onSelected: _selectChip,
            ),
            const SizedBox(height: 16),
            if (_loading && _tiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: FirstVueColors.teal),
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: _tiles.length,
                itemBuilder: (context, index) {
                  final tile = _tiles[index];
                  return SocialPostTile(
                    handle: tile.handle,
                    avatarUrl: tile.avatarUrl,
                    imageUrl: tile.imageUrl,
                    assetImage: tile.assetImage,
                    videoUrl: tile.videoUrl,
                    likeLabel: tile.likeLabel,
                    dateLabel: tile.dateLabel,
                    showPlay: tile.isVideo && tile.videoUrl == null,
                    showFollowOverlay: tile.showFollowOverlay,
                    onTap: tile.onTap,
                  );
                },
              ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FirstVueColors.teal,
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: _hasMore ? _loadMore : _reload,
                    child: Text(
                      _error!,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                  ),
                ),
            ],
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

class _ExploreCategoryHeader extends StatelessWidget {
  final _ExploreChip? selected;
  final ValueChanged<_ExploreChip> onSelected;

  const _ExploreCategoryHeader({
    required this.selected,
    required this.onSelected,
  });

  static const _labels = <_ExploreChip, String>{
    _ExploreChip.businesses: 'Businesses',
    _ExploreChip.people: 'People',
    _ExploreChip.events: 'Events',
    _ExploreChip.thingsToDo: 'Things to Do',
    _ExploreChip.food: 'Food',
    _ExploreChip.bars: 'Bars',
  };

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final chip = _labels.keys.elementAt(index);
          final label = _labels[chip]!;
          final isSelected = selected == chip;
          return GestureDetector(
            onTap: () => onSelected(chip),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                color: isSelected ? FirstVueColors.gold : fv.secondaryText,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 2,
                    width: isSelected ? 22 : 0,
                    decoration: BoxDecoration(
                      color: FirstVueColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExploreFilterResult {
  final String? profileType;
  final String? businessType;

  const _ExploreFilterResult({this.profileType, this.businessType});
}

class _ExploreFilterSheet extends StatefulWidget {
  final String? profileType;
  final String? businessType;

  const _ExploreFilterSheet({this.profileType, this.businessType});

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late String? _profileType = widget.profileType;
  late String? _businessType = widget.businessType;

  static const _profileTypes = <(String, String)>[
    ('user', 'People'),
    ('business', 'Business'),
    ('professional', 'Professional'),
    ('event', 'Event'),
    ('community', 'Community'),
  ];

  List<String> get _businessTypes {
    final values = <String>{};
    for (final group in businessCategoryGroups.values) {
      values.addAll(group);
    }
    return values.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: fv.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Filters',
              style: TextStyle(
                color: fv.primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile type',
              style: TextStyle(
                color: FirstVueColors.gold.withValues(alpha: .95),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _profileTypes)
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _profileType == entry.$1,
                    onSelected: (selected) {
                      setState(() => _profileType = selected ? entry.$1 : null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Business type',
              style: TextStyle(
                color: FirstVueColors.gold.withValues(alpha: .95),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _businessTypes)
                      ChoiceChip(
                        label: Text(type),
                        selected: _businessType == type,
                        onSelected: (selected) {
                          setState(
                            () => _businessType = selected ? type : null,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _profileType = null;
                      _businessType = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      _ExploreFilterResult(
                        profileType: _profileType,
                        businessType: _businessType,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreTile {
  final String? postId;
  final DateTime? createdAt;
  final String handle;
  final String? imageUrl;
  final String? assetImage;
  final String? videoUrl;
  final String? avatarUrl;
  final String? likeLabel;
  final String? dateLabel;
  final bool isVideo;
  final bool showFollowOverlay;
  final VoidCallback onTap;

  const _ExploreTile({
    required this.handle,
    required this.onTap,
    this.postId,
    this.createdAt,
    this.imageUrl,
    this.assetImage,
    this.videoUrl,
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
              Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
