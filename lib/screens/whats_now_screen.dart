import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';

import '../screens/firstvue_business_profile_screen.dart';
import '../services/community_news_service.dart';
import '../services/things_to_do_service.dart';
import '../services/trending_businesses_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/feed_comments_sheet.dart';

const _screenBackground = Color(0xFF080B0F);

class WhatsNowScreen extends StatefulWidget {
  const WhatsNowScreen({super.key});

  @override
  State<WhatsNowScreen> createState() => _WhatsNowScreenState();
}

class _WhatsNowScreenState extends State<WhatsNowScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _tabsReady = false;
  bool _showComingSoon = false;

  final _tabLabels = <String>['Trending', 'New', 'Recommended'];

  @override
  void initState() {
    super.initState();
    _initTabs();
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
      'Trending' => TrendingBusinessesService.fetchTrendingNearYou(limit: 20),
      'New' => TrendingBusinessesService.fetchNewNearYou(limit: 20),
      'Recommended' =>
        TrendingBusinessesService.fetchRecommendedNearYou(limit: 20),
      'Coming Soon' =>
        TrendingBusinessesService.fetchComingSoonNearYou(limit: 20),
      _ => TrendingBusinessesService.fetchTrendingNearYou(limit: 20),
    };
  }

  Future<void> _refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: AppBar(
        backgroundColor: _screenBackground,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "WHAT'S NOW",
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 22,
            letterSpacing: 1.6,
            color: FirstVueColors.gold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: FirstVueColors.gold,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Live trending picks and local events in one feed.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .62),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel(
              title: "WHAT'S TRENDING",
              accent: FirstVueColors.coral,
            ),
            const SizedBox(height: 12),
            if (!_tabsReady)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: FirstVueColors.teal),
                ),
              )
            else ...[
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: FirstVueColors.gold,
                unselectedLabelColor: Colors.white54,
                indicatorColor: FirstVueColors.coral,
                tabs: _labels
                    .map((label) => Tab(text: label.toUpperCase()))
                    .toList(),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final label = _labels[_tabController.index];
                  return _TrendingFeedTab(
                    key: ValueKey(label),
                    label: label,
                    loadBusinesses: () => _loadBusinessesForLabel(label),
                  );
                },
              ),
            ],
            const SizedBox(height: 28),
            const _SectionLabel(
              title: 'EVENTS',
              accent: FirstVueColors.teal,
            ),
            const SizedBox(height: 12),
            const _EventsFeedSection(),
            const SizedBox(height: 28),
            const _SectionLabel(
              title: 'COMMUNITY PULSE',
              accent: FirstVueColors.gold,
            ),
            const SizedBox(height: 12),
            const _CommunityPulseSection(),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final Color accent;

  const _SectionLabel({required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: FirstVueColors.ivory,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _TrendingFeedTab extends StatelessWidget {
  final String label;
  final Future<List<TrendingBusiness>> Function() loadBusinesses;

  const _TrendingFeedTab({
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
          return const _FeedEmptyCard(
            message: 'Trending is unavailable right now.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          );
        }
        final businesses = snapshot.data!;
        if (businesses.isEmpty) {
          return _FeedEmptyCard(message: 'No $label listings yet.');
        }
        return Column(
          children: [
            for (var i = 0; i < businesses.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == businesses.length - 1 ? 0 : 12),
                child: _TrendingFeedCard(
                  business: businesses[i],
                  accent: i.isEven ? FirstVueColors.teal : FirstVueColors.coral,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrendingFeedCard extends StatelessWidget {
  final TrendingBusiness business;
  final Color accent;

  const _TrendingFeedCard({
    required this.business,
    required this.accent,
  });

  String get _category =>
      business.services.isNotEmpty ? business.services.first : 'Verified';

  String get _ratingText {
    if (business.rating <= 0) return 'New';
    final reviews =
        business.reviewCount > 0 ? ' (${business.reviewCount})' : '';
    return '${business.rating.toStringAsFixed(1)}$reviews';
  }

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      business.imageUrl != null
                          ? Image.network(
                              business.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Image.asset(
                                'assets/images/explore_barbershops.jpg',
                                fit: BoxFit.cover,
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
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: .55),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: FirstVueColors.gold,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _ratingText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (business.distanceMiles != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.near_me_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: .5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${business.distanceMiles!.toStringAsFixed(1)} mi',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventsFeedSection extends StatelessWidget {
  const _EventsFeedSection();

  String _formatEventDate(DateTime? date) {
    if (date == null) return 'Date TBA';
    final local = date.toLocal();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekday = weekdays[local.weekday - 1];
    final month = months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$weekday, $month ${local.day} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityEvent>>(
      future: ThingsToDoService.fetchApprovedEvents(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _FeedEmptyCard(
            message: 'Events are unavailable right now.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          );
        }
        final events = snapshot.data!;
        if (events.isEmpty) {
          return const _FeedEmptyCard(
            message: 'Local events will appear here.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < events.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == events.length - 1 ? 0 : 12),
                child: _EventFeedCard(
                  event: events[i],
                  dateLabel: _formatEventDate(events[i].eventAt),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventFeedCard extends StatelessWidget {
  final CommunityEvent event;
  final String dateLabel;

  const _EventFeedCard({
    required this.event,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FirstVueColors.teal.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_activity_outlined,
                color: FirstVueColors.teal,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    color: FirstVueColors.teal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (event.businessName != null) ...[
            const SizedBox(height: 4),
            Text(
              event.businessName!,
              style: const TextStyle(
                color: FirstVueColors.gold,
                fontSize: 12,
              ),
            ),
          ],
          if (event.locationLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Colors.white.withValues(alpha: .5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event.locationLabel!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (event.description != null &&
              event.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.description!,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityPulseSection extends StatefulWidget {
  const _CommunityPulseSection();

  @override
  State<_CommunityPulseSection> createState() => _CommunityPulseSectionState();
}

class _CommunityPulseSectionState extends State<_CommunityPulseSection> {
  late Future<List<CommunityNewsPost>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = CommunityNewsService.fetchPosts(limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityNewsPost>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _FeedEmptyCard(
            message: 'Community updates are unavailable right now.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          );
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return const _FeedEmptyCard(
            message: 'Community posts will appear here.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < posts.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == posts.length - 1 ? 0 : 10),
                child: _PulsePostCard(post: posts[i]),
              ),
          ],
        );
      },
    );
  }
}

class _PulsePostCard extends StatelessWidget {
  final CommunityNewsPost post;

  const _PulsePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.authorName,
                  style: const TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (post.businessName != null)
                Text(
                  post.businessName!,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.body,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 16,
                color: post.sparkedByMe
                    ? FirstVueColors.gold
                    : Colors.white.withValues(alpha: .5),
              ),
              const SizedBox(width: 4),
              Text(
                '${post.sparkCount} sparks',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .6),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => FeedCommentsSheet.show(
                  context,
                  mediaId: post.commentsMediaId,
                  businessName: post.authorName,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Comment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedEmptyCard extends StatelessWidget {
  final String message;

  const _FeedEmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white54)),
    );
  }
}
