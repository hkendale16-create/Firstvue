import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../screens/create_shoutout_screen.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../services/recommendations_service.dart';
import '../services/shoutout_service.dart';
import '../services/things_to_do_service.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import 'event_profile_sheet.dart';
import 'shoutout_card.dart';
import 'social_chrome.dart';

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
        const PeopleToFollowRow(),
        const SizedBox(height: 22),
        SocialPillTabs(
          labels: _labels,
          selectedIndex: _tabController.index,
          onSelected: (index) {
            _tabController.index = index;
            setState(() {});
          },
        ),
        const SizedBox(height: 14),
        if (_labels[_tabController.index] == 'Events')
          const _EventsFeedList()
        else
          _BusinessFeedList(
            key: ValueKey('${_labels[_tabController.index]}-${widget.refreshToken}'),
            label: _labels[_tabController.index],
            loadBusinesses: () =>
                _loadBusinessesForLabel(_labels[_tabController.index]),
          ),
        const SizedBox(height: 22),
        SocialSectionHeader(
          title: 'Shoutouts',
          actionLabel: 'Create',
          onAction: () async {
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
              selectedColor: FirstVueColors.gold,
              labelStyle: TextStyle(
                color: _shoutoutSort == ShoutoutSort.popular
                    ? const Color(0xFF17130B)
                    : context.fv.secondaryText,
                fontSize: 12,
              ),
              backgroundColor: context.fv.elevatedSurface,
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
              selectedColor: FirstVueColors.gold,
              labelStyle: TextStyle(
                color: _shoutoutSort == ShoutoutSort.newest
                    ? const Color(0xFF17130B)
                    : context.fv.secondaryText,
                fontSize: 12,
              ),
              backgroundColor: context.fv.elevatedSurface,
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final items = snapshot.data ?? const <Shoutout>[];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Be the first to shout out a local favorite.',
                  style: TextStyle(color: context.fv.secondaryText),
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

class _BusinessFeedList extends StatelessWidget {
  final String label;
  final Future<List<TrendingBusiness>> Function() loadBusinesses;

  const _BusinessFeedList({
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
        return Column(
          children: [
            for (final business in businesses) ...[
              SocialFeedCard(
                name: business.name,
                handle: '@${business.name.toLowerCase().replaceAll(' ', '')}',
                body: business.services.isEmpty
                    ? 'Verified on FirstVue'
                    : business.services.take(3).join(' • '),
                imageUrl: business.imageUrl,
                assetImage: 'assets/images/explore_barbershops.jpg',
                meta: business.rating > 0
                    ? '${business.rating.toStringAsFixed(1)}★'
                    : null,
                onTap: () => Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => FirstVueBusinessProfileScreen(
                      businessId: business.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _EventsFeedList extends StatelessWidget {
  const _EventsFeedList();

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
        return Column(
          children: [
            for (final event in events) ...[
              SocialFeedCard(
                name: event.title,
                handle: 'Event',
                body: event.locationLabel ?? 'Local event',
                assetImage: 'assets/images/explore_things_to_do.jpg',
                onTap: () => EventProfileSheet.show(context, event: event),
              ),
              const SizedBox(height: 12),
            ],
          ],
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
      child: Text(message, style: TextStyle(color: context.fv.secondaryText)),
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
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Personalized picks will appear here as you explore.',
              style: TextStyle(color: context.fv.secondaryText),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle) ...[
              const SizedBox(height: 24),
              Text(
                'YOU MIGHT LIKE',
                style: TextStyle(
                  color: context.fv.primaryText,
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
                              style: TextStyle(
                                color: context.fv.primaryText,
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
                              style: TextStyle(
                                color: context.fv.secondaryText,
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
