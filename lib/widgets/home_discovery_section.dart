import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../screens/firstvue_business_profile_screen.dart';
import '../screens/people_to_follow_screen.dart';
import '../services/recommendations_service.dart';
import '../services/things_to_do_service.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import 'home_community_feed_block.dart';
import 'social_chrome.dart';

class HomeDiscoverySection extends StatefulWidget {
  final int refreshToken;

  const HomeDiscoverySection({
    super.key,
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

  final _tabLabels = <String>[
    'Trending',
    'New',
    'Recommended',
    'Events',
    'Communities',
  ];

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  @override
  void didUpdateWidget(covariant HomeDiscoverySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken && _tabsReady) {
      setState(() {});
    }
  }

  Future<void> _initTabs() async {
    final hasComingSoon =
        await TrendingBusinessesService.hasComingSoonBusinesses();
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
      'Recommended' =>
        TrendingBusinessesService.fetchRecommendedNearYou(limit: 16),
      'Coming Soon' =>
        TrendingBusinessesService.fetchComingSoonNearYou(limit: 16),
      _ => TrendingBusinessesService.fetchTrendingNearYou(limit: 16),
    };
  }

  void _openPeopleToFollow() {
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const PeopleToFollowScreen()),
    );
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

    final label = _labels[_tabController.index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SocialPillTabs(
          labels: _labels,
          selectedIndex: _tabController.index,
          onSelected: (index) {
            _tabController.index = index;
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        if (label == 'Events')
          const _EventsFeedList()
        else if (label == 'Communities')
          HomeCommunityFeedBlock(refreshToken: widget.refreshToken)
        else
          _MixedSocialFeed(
            key: ValueKey('$label-${widget.refreshToken}'),
            label: label,
            loadBusinesses: () => _loadBusinessesForLabel(label),
            onSeeAllPeople: _openPeopleToFollow,
          ),
      ],
    );
  }
}

class _MixedSocialFeed extends StatelessWidget {
  final String label;
  final Future<List<TrendingBusiness>> Function() loadBusinesses;
  final VoidCallback onSeeAllPeople;

  const _MixedSocialFeed({
    super.key,
    required this.label,
    required this.loadBusinesses,
    required this.onSeeAllPeople,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrendingBusiness>>(
      future: loadBusinesses(),
      builder: (context, snapshot) {
        final businesses = snapshot.data ?? const <TrendingBusiness>[];
        final waiting = snapshot.connectionState == ConnectionState.waiting &&
            businesses.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: FirstVueColors.teal),
                ),
              )
            else if (businesses.isNotEmpty)
              _businessCard(context, businesses.first),
            const SizedBox(height: 18),
            PeopleToFollowRow(onSeeAll: onSeeAllPeople),
            const SizedBox(height: 18),
            const _FeaturedEventCard(),
            if (businesses.length > 1) ...[
              const SizedBox(height: 18),
              for (final business in businesses.skip(1)) ...[
                _businessCard(context, business),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _businessCard(BuildContext context, TrendingBusiness business) {
    final caption = business.services.isEmpty
        ? 'Verified on FirstVue. Book your appointment and start your weekend right.'
        : '${business.services.take(3).join(' • ')}. Book your appointment and start your weekend right.';
    return SocialFeedCard(
      name: business.name,
      handle: socialHandleFromName(business.name),
      body: caption,
      imageUrl: business.imageUrl,
      assetImage: 'assets/images/explore_barbershops.jpg',
      meta: '2h',
      verified: business.verified,
      likeCount: business.reviewCount > 0 ? business.reviewCount : 128,
      commentCount: 12,
      shareCount: 8,
      onTap: () => Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => FirstVueBusinessProfileScreen(
            businessId: business.id,
          ),
        ),
      ),
    );
  }
}

class _FeaturedEventCard extends StatelessWidget {
  const _FeaturedEventCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ThingsToDoService.fetchApprovedEvents(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <CommunityEvent>[];
        if (events.isEmpty) return const SizedBox.shrink();
        return SocialEventCard(event: events.first);
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
          return Text(
            'Local events will appear here.',
            style: TextStyle(color: context.fv.secondaryText),
          );
        }
        return Column(
          children: [
            for (final event in events) ...[
              SocialEventCard(event: event),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
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
                          color: context.fv.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: context.fv.borderSubtle,
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
