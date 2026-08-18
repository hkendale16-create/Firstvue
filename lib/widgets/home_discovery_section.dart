import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/ensure_signed_in.dart';
import '../config/app_config.dart';
import '../models/growth_prompt.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/firstvue_business_profile_screen.dart';
import '../screens/people_to_follow_screen.dart';
import '../screens/rentals_screen.dart';
import '../services/event_time_windows.dart';
import '../services/growth_prompt_catalog.dart';
import '../services/recommendations_service.dart';
import '../services/rentals_store.dart';
import '../services/saved_items_service.dart';
import '../services/things_to_do_service.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import 'feed_comments_sheet.dart';
import 'firstvue_share_sheet.dart';
import 'growth_prompt.dart';
import 'home_communities_section.dart';
import 'earn_on_firstvue_card.dart';
import 'social_chrome.dart';
import 'whats_on_near_you.dart';

class HomeDiscoverySection extends StatefulWidget {
  final int refreshToken;
  final VoidCallback? onSetCity;

  const HomeDiscoverySection({
    super.key,
    this.refreshToken = 0,
    this.onSetCity,
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
    'Rentals',
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
      'Recommended' => TrendingBusinessesService.fetchRecommendedNearYou(
        limit: 16,
      ),
      'Coming Soon' => TrendingBusinessesService.fetchComingSoonNearYou(
        limit: 16,
      ),
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
        WhatsOnNearYou(
          refreshToken: widget.refreshToken,
          onSetCity: widget.onSetCity,
        ),
        const EarnOnFirstVueCard(),
        const SizedBox(height: 16),
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
          HomeCommunitiesSection(refreshToken: widget.refreshToken)
        else if (label == 'Rentals')
          const _HomeRentalsSection()
        else
          _MixedSocialFeed(
            key: ValueKey(label),
            label: label,
            refreshToken: widget.refreshToken,
            loadBusinesses: () => _loadBusinessesForLabel(label),
            onSeeAllPeople: _openPeopleToFollow,
            showPeopleToFollow: label == 'Recommended' || label == 'Trending',
          ),
      ],
    );
  }
}

class _MixedSocialFeed extends StatefulWidget {
  final String label;
  final int refreshToken;
  final Future<List<TrendingBusiness>> Function() loadBusinesses;
  final VoidCallback onSeeAllPeople;
  final bool showPeopleToFollow;

  const _MixedSocialFeed({
    super.key,
    required this.label,
    required this.refreshToken,
    required this.loadBusinesses,
    required this.onSeeAllPeople,
    this.showPeopleToFollow = false,
  });

  @override
  State<_MixedSocialFeed> createState() => _MixedSocialFeedState();
}

class _MixedSocialFeedState extends State<_MixedSocialFeed> {
  late Future<List<TrendingBusiness>> _future;
  List<TrendingBusiness> _businesses = const [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _MixedSocialFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label ||
        oldWidget.refreshToken != widget.refreshToken) {
      _future = _load();
    }
  }

  Future<List<TrendingBusiness>> _load() async {
    final items = await widget.loadBusinesses();
    if (mounted) {
      setState(() => _businesses = items);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrendingBusiness>>(
      future: _future,
      builder: (context, snapshot) {
        // Prefer last good data so parent rebuilds / soft refreshes do not blank.
        final businesses = snapshot.data ?? _businesses;
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
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
            else if (businesses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label == 'Coming Soon'
                          ? 'No coming-soon listings near you yet.'
                          : 'Nothing nearby in this list yet. Follow people or try another city.',
                      style: TextStyle(color: context.fv.secondaryText),
                    ),
                    if (!widget.showPeopleToFollow) ...[
                      const SizedBox(height: 16),
                      PeopleToFollowRow(onSeeAll: widget.onSeeAllPeople),
                    ],
                  ],
                ),
              )
            else if (businesses.isNotEmpty)
              _InteractiveBusinessCard(business: businesses.first),
            if (widget.showPeopleToFollow) ...[
              const SizedBox(height: 18),
              PeopleToFollowRow(onSeeAll: widget.onSeeAllPeople),
            ],
            const SizedBox(height: 18),
            const _FeaturedEventCard(),
            if (businesses.length > 1) ...[
              const SizedBox(height: 18),
              for (final business in businesses.skip(1)) ...[
                _InteractiveBusinessCard(business: business),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _InteractiveBusinessCard extends StatefulWidget {
  final TrendingBusiness business;

  const _InteractiveBusinessCard({required this.business});

  @override
  State<_InteractiveBusinessCard> createState() =>
      _InteractiveBusinessCardState();
}

class _InteractiveBusinessCardState extends State<_InteractiveBusinessCard> {
  bool _liked = false;
  bool _saved = false;
  bool _busy = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.business.reviewCount > 0
        ? widget.business.reviewCount
        : 128;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final ids = await SavedItemsService.fetchSavedIds(
      contentType: SavedContentType.business,
      contentIds: [widget.business.id],
    );
    if (!mounted) return;
    setState(() {
      _saved = ids.contains(widget.business.id);
      _liked = _saved;
    });
  }

  Future<bool> _ensureSignedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return true;
    await ensureSignedIn(context);
    if (!mounted) return false;
    return Supabase.instance.client.auth.currentUser != null;
  }

  void _openProfile() {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) =>
            FirstVueBusinessProfileScreen(businessId: widget.business.id),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!await _ensureSignedIn()) return;
      if (!mounted) return;
    }
    setState(() => _busy = true);
    final previousLiked = _liked;
    final previousCount = _likeCount;
    setState(() {
      _liked = !_liked;
      _likeCount = _liked ? _likeCount + 1 : (_likeCount - 1).clamp(0, 999999);
    });
    try {
      final saved = await SavedItemsService.toggleSave(
        contentType: SavedContentType.business,
        contentId: widget.business.id,
        currentlySaved: previousLiked,
      );
      if (!mounted) return;
      setState(() {
        _liked = saved;
        _saved = saved;
        _busy = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likeCount = previousCount;
        _busy = false;
      });
      if (await _ensureSignedIn() && mounted) {
        await _toggleLike();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _likeCount = previousCount;
        _busy = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_busy) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      if (!await _ensureSignedIn()) return;
      if (!mounted) return;
    }
    setState(() => _busy = true);
    final previous = _saved;
    setState(() => _saved = !_saved);
    try {
      final saved = await SavedItemsService.toggleSave(
        contentType: SavedContentType.business,
        contentId: widget.business.id,
        currentlySaved: previous,
      );
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _liked = saved;
        _busy = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _saved = previous;
        _busy = false;
      });
      if (await _ensureSignedIn() && mounted) {
        await _toggleSave();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saved = previous;
        _busy = false;
      });
    }
  }

  Future<void> _share() async {
    await FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: widget.business.name,
        link: AppConfig.businessShareUrl(widget.business.id),
        subtitle: 'Discover this business on FirstVue',
      ),
    );
  }

  Future<void> _openComments() async {
    await FeedCommentsSheet.show(
      context,
      mediaId: 'business:${widget.business.id}',
      businessName: widget.business.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
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
      likeCount: _likeCount,
      commentCount: 12,
      shareCount: 8,
      liked: _liked,
      saved: _saved,
      onProfileTap: _openProfile,
      onTap: _openProfile,
      onLike: _toggleLike,
      onComment: _openComments,
      onShare: _share,
      onSave: _toggleSave,
      followBusinessId: business.id,
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
      future: Future.wait([
        ThingsToDoService.fetchRecentlyPostedEvents(limit: 12),
        ThingsToDoService.fetchApprovedEvents(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: FirstVueColors.teal),
          );
        }
        final recent = snapshot.data![0];
        final upcomingAll = snapshot.data![1];
        final now = DateTime.now();
        final tonight = EventTimeWindows.tonight(upcomingAll, now: now);
        final tonightIds = {for (final event in tonight) event.id};
        final weekend = [
          for (final event in EventTimeWindows.thisWeekend(upcomingAll, now: now))
            if (!tonightIds.contains(event.id)) event,
        ];
        final timedIds = {...tonightIds, for (final event in weekend) event.id};
        final recentIds = {for (final e in recent) e.id};
        final upcoming = [
          for (final event in upcomingAll)
            if (!recentIds.contains(event.id) && !timedIds.contains(event.id))
              event,
        ];
        if (recent.isEmpty &&
            upcoming.isEmpty &&
            tonight.isEmpty &&
            weekend.isEmpty) {
          return GrowthPrompt(
            spec: GrowthPromptCatalog.emptyEvents(),
            variant: GrowthPromptVariant.empty,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tonight.isNotEmpty) ...[
              Text(
                'Tonight',
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              for (final event in tonight) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
            if (weekend.isNotEmpty) ...[
              Text(
                'This weekend',
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              for (final event in weekend) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
            if (recent.isNotEmpty) ...[
              Text(
                'Recently Posted',
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              for (final event in recent) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
            ],
            if (upcoming.isNotEmpty) ...[
              Text(
                'Upcoming',
                style: TextStyle(
                  color: context.fv.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              for (final event in upcoming) ...[
                SocialEventCard(event: event),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _HomeRentalsSection extends StatelessWidget {
  const _HomeRentalsSection();

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return FutureBuilder<List<RentalListing>>(
      future: RentalsStore.fetchApprovedListings(limit: 12),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Unable to load rentals.',
            style: TextStyle(color: fv.secondaryText),
          );
        }
        final listings = snapshot.data ?? const <RentalListing>[];
        if (listings.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No rentals nearby yet.',
                style: TextStyle(color: fv.secondaryText),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(builder: (_) => const RentalsScreen()),
                  );
                },
                child: const Text('Browse rentals'),
              ),
            ],
          );
        }
        return Column(
          children: [
            for (final listing in listings) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.home_work_outlined, color: fv.primaryText),
                title: Text(
                  listing.title,
                  style: TextStyle(
                    color: fv.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  listing.location,
                  style: TextStyle(color: fv.secondaryText, fontSize: 12),
                ),
                trailing: Text(
                  listing.monthlyPrice ?? listing.weeklyPrice ?? '',
                  style: const TextStyle(color: FirstVueColors.gold),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    FirstVuePageRoute(builder: (_) => const RentalsScreen()),
                  );
                },
              ),
              Divider(color: fv.divider, height: 1),
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
                          border: Border.all(color: context.fv.borderSubtle),
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
