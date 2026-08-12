import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../screens/create_shoutout_screen.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../services/recommendations_service.dart';
import '../services/shoutout_service.dart';
import '../services/things_to_do_service.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import 'shoutout_card.dart';

class HomeDiscoverySection extends StatefulWidget {
  final VoidCallback onViewAllVue;
  final int refreshToken;

  const HomeDiscoverySection({
    super.key,
    required this.onViewAllVue,
    this.refreshToken = 0,
  });

  @override
  State<HomeDiscoverySection> createState() => _HomeDiscoverySectionState();
}

class _HomeDiscoverySectionState extends State<HomeDiscoverySection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showComingSoon = false;
  bool _tabsReady = false;
  ShoutoutSort _shoutoutSort = ShoutoutSort.popular;
  late Future<List<Shoutout>> _shoutoutsFuture;

  final _tabLabels = <String>['Trending', 'New', 'Recommended', 'Events'];

  @override
  void initState() {
    super.initState();
    _shoutoutsFuture = _loadShoutouts();
    _initTabs();
  }

  @override
  void didUpdateWidget(covariant HomeDiscoverySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _shoutoutsFuture = _loadShoutouts();
    }
  }

  Future<List<Shoutout>> _loadShoutouts() {
    return ShoutoutService.fetchFeed(sort: _shoutoutSort, limit: 8);
  }

  Future<void> _initTabs() async {
    final hasComingSoon = await TrendingBusinessesService.hasComingSoonBusinesses();
    if (!mounted) return;
    setState(() {
      _showComingSoon = hasComingSoon;
      _tabController = TabController(length: _labels.length, vsync: this);
      _tabsReady = true;
    });
  }

  List<String> get _labels {
    final labels = [..._tabLabels];
    if (_showComingSoon) labels.add('Coming Soon');
    return labels;
  }

  @override
  void dispose() {
    if (_tabsReady) _tabController.dispose();
    super.dispose();
  }

  Future<List<TrendingBusiness>> _loadBusinessesForLabel(String label) {
    return switch (label) {
      'Trending' => TrendingBusinessesService.fetchTrendingNearYou(limit: 16),
      'New' => TrendingBusinessesService.fetchNewNearYou(limit: 16),
      'Recommended' => TrendingBusinessesService.fetchRecommendedNearYou(limit: 16),
      'Coming Soon' => TrendingBusinessesService.fetchComingSoonNearYou(limit: 16),
      _ => TrendingBusinessesService.fetchTrendingNearYou(limit: 16),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_tabsReady) {
      return const SizedBox(
        height: 320,
        child: Center(
          child: CircularProgressIndicator(color: FirstVueColors.teal),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'TRENDING NEAR YOU',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onViewAllVue,
              style: TextButton.styleFrom(
                foregroundColor: FirstVueColors.coral,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'VIEW ALL  >',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: FirstVueColors.gold,
          unselectedLabelColor: Colors.white54,
          indicatorColor: FirstVueColors.coral,
          onTap: (_) => setState(() {}),
          tabs: _labels.map((label) => Tab(text: label.toUpperCase())).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 248,
          child: TabBarView(
            controller: _tabController,
            children: _labels.map((label) {
              if (label == 'Events') {
                return _EventsSwipeList(
                  key: ValueKey('events-${widget.refreshToken}'),
                );
              }
              return _BusinessSwipeList(
                key: ValueKey('$label-${widget.refreshToken}'),
                label: label,
                loadBusinesses: () => _loadBusinessesForLabel(label),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: Text(
                'SHOUTOUTS',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => const CreateShoutoutScreen(),
                  ),
                );
                if (created != null && mounted) {
                  setState(() => _shoutoutsFuture = _loadShoutouts());
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: FirstVueColors.coral,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Create', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Popular'),
              selected: _shoutoutSort == ShoutoutSort.popular,
              onSelected: (_) {
                if (_shoutoutSort == ShoutoutSort.popular) return;
                setState(() {
                  _shoutoutSort = ShoutoutSort.popular;
                  _shoutoutsFuture = _loadShoutouts();
                });
              },
              selectedColor: FirstVueColors.gold.withValues(alpha: .25),
              labelStyle: TextStyle(
                color: _shoutoutSort == ShoutoutSort.popular
                    ? FirstVueColors.gold
                    : Colors.white54,
                fontSize: 12,
              ),
              backgroundColor: FirstVueColors.surface,
              side: BorderSide.none,
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Newest'),
              selected: _shoutoutSort == ShoutoutSort.newest,
              onSelected: (_) {
                if (_shoutoutSort == ShoutoutSort.newest) return;
                setState(() {
                  _shoutoutSort = ShoutoutSort.newest;
                  _shoutoutsFuture = _loadShoutouts();
                });
              },
              selectedColor: FirstVueColors.gold.withValues(alpha: .25),
              labelStyle: TextStyle(
                color: _shoutoutSort == ShoutoutSort.newest
                    ? FirstVueColors.gold
                    : Colors.white54,
                fontSize: 12,
              ),
              backgroundColor: FirstVueColors.surface,
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Shoutout>>(
          future: _shoutoutsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
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
              );
            }
            final items = snapshot.data ?? const <Shoutout>[];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Be the first to shout out a local favorite.',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            return Column(
              children: [
                for (final shoutout in items)
                  ShoutoutCard(shoutout: shoutout, compact: true),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BusinessSwipeList extends StatelessWidget {
  final String label;
  final Future<List<TrendingBusiness>> Function() loadBusinesses;

  const _BusinessSwipeList({
    super.key,
    required this.label,
    required this.loadBusinesses,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrendingBusiness>>(
      future: loadBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _TrendingEmptyCard(
            message: 'Discovery is unavailable right now.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: FirstVueColors.teal),
          );
        }
        final businesses = snapshot.data!;
        if (businesses.isEmpty) {
          return _TrendingEmptyCard(
            message: 'No $label listings yet.',
          );
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: businesses.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final business = businesses[index];
            final accent =
                index.isEven ? FirstVueColors.teal : FirstVueColors.coral;
            return _TrendingPortraitCard(
              business: business,
              accent: accent,
              onTap: () => Navigator.push(
                context,
                FirstVuePageRoute(
                  builder: (_) => FirstVueBusinessProfileScreen(
                    businessId: business.id,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EventsSwipeList extends StatelessWidget {
  const _EventsSwipeList({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ThingsToDoService.fetchApprovedEvents(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: FirstVueColors.teal),
          );
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return const _TrendingEmptyCard(
            message: 'Local events will appear here.',
          );
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final event = events[index];
            return Container(
              width: 220,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FirstVueColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: FirstVueColors.coral.withValues(alpha: .35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.local_activity, color: FirstVueColors.coral),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event.locationLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.locationLabel!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TrendingEmptyCard extends StatelessWidget {
  final String message;

  const _TrendingEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: const TextStyle(color: Colors.white54)),
    );
  }
}

class _TrendingPortraitCard extends StatelessWidget {
  final TrendingBusiness business;
  final Color accent;
  final VoidCallback onTap;

  const _TrendingPortraitCard({
    required this.business,
    required this.accent,
    required this.onTap,
  });

  String get _category =>
      business.services.isNotEmpty ? business.services.first : 'Verified';

  String get _ratingText {
    if (business.rating <= 0) return 'New';
    final reviews = business.reviewCount > 0 ? ' (${business.reviewCount})' : '';
    return '${business.rating.toStringAsFixed(1)}$reviews';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 156,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .42)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              fit: StackFit.expand,
              children: [
                business.imageUrl != null && !business.featuredIsVideo
                    ? Image.network(
                        business.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/explore_barbershops.jpg',
                          fit: BoxFit.cover,
                        ),
                      )
                    : business.featuredIsVideo
                    ? Container(
                        color: FirstVueColors.elevatedSurface,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline, color: FirstVueColors.teal, size: 44),
                            SizedBox(height: 6),
                            Text('VIDEO', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      )
                    : Image.asset(
                        'assets/images/explore_barbershops.jpg',
                        fit: BoxFit.cover,
                      ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 0.75, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .35),
                        Colors.black.withValues(alpha: .88),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: FirstVueColors.gold,
                            size: 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _ratingText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YouMightLikeSection extends StatefulWidget {
  final bool showTitle;

  const YouMightLikeSection({super.key, this.showTitle = true});

  @override
  State<YouMightLikeSection> createState() => _YouMightLikeSectionState();
}

class _YouMightLikeSectionState extends State<YouMightLikeSection> {
  late Future<List<TrendingBusiness>> _future;

  @override
  void initState() {
    super.initState();
    _future = RecommendationsService.fetchYouMightLike();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrendingBusiness>>(
      future: _future,
      builder: (context, snapshot) {
        final businesses = snapshot.data ?? const [];
        if (businesses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Personalized picks will appear here as you explore.',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              const SizedBox(height: 24),
              const Text(
                'YOU MIGHT LIKE',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: businesses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final business = businesses[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        FirstVuePageRoute(
                          builder: (_) => FirstVueBusinessProfileScreen(
                            businessId: business.id,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        width: 220,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FirstVueColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: FirstVueColors.teal.withValues(alpha: .28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              business.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              business.services.isNotEmpty
                                  ? business.services.first
                                  : 'Based on your recent searches',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
