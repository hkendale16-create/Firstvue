import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/community_hub_detail_screen.dart';
import '../screens/create_community_hub_screen.dart';
import '../screens/create_community_screen.dart';
import '../screens/whats_now_screen.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../services/recommendations_service.dart';
import '../theme/firstvue_theme.dart';
import 'group_circle_avatar.dart';
import 'home_discovery_section.dart';

/// Horizontal discovery carousel on Home: Communities, recommendations,
/// What's Now, Explore, and Rate Local Pros.
class HomeDiscoverySwipe extends StatefulWidget {
  final int refreshToken;
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenVue;

  const HomeDiscoverySwipe({
    super.key,
    this.refreshToken = 0,
    required this.onOpenExplore,
    required this.onOpenVue,
  });

  @override
  State<HomeDiscoverySwipe> createState() => _HomeDiscoverySwipeState();
}

class _HomeDiscoverySwipeState extends State<HomeDiscoverySwipe> {
  final _pageController = PageController();
  int _page = 0;

  static const _pageCount = 5;
  static const _pageHeight = 480.0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _pageHeight,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _page = index),
            children: [
              _SwipePageShell(
                title: 'Communities',
                child: _CommunitiesSwipePage(
                  refreshToken: widget.refreshToken,
                ),
              ),
              _SwipePageShell(
                title: 'What You Might Like',
                trailing: TextButton(
                  onPressed: widget.onOpenVue,
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
                child: const YouMightLikeSection(showTitle: false),
              ),
              _SwipePageShell(
                title: "What's Now",
                child: WhatsNowEntryCard(
                  onTap: () {
                    RecommendationsService.recordCategoryVisit('whats_now');
                    Navigator.push(
                      context,
                      FirstVuePageRoute(
                        builder: (_) => const WhatsNowScreen(),
                      ),
                    );
                  },
                ),
              ),
              _SwipePageShell(
                title: 'Explore',
                child: _DiscoveryActionCard(
                  icon: Icons.explore_outlined,
                  accent: FirstVueColors.teal,
                  title: 'Explore the city',
                  subtitle: 'Barbers, beauty, dining, rentals & more',
                  onTap: widget.onOpenExplore,
                ),
              ),
              _SwipePageShell(
                title: 'Rate Local Pros',
                child: _DiscoveryActionCard(
                  icon: Icons.star_outline_rounded,
                  accent: FirstVueColors.gold,
                  title: 'Rate local pros',
                  subtitle: 'Discover & review businesses near you',
                  onTap: widget.onOpenExplore,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pageCount, (index) {
            final active = index == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? FirstVueColors.teal
                    : Colors.white.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SwipePageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SwipePageShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: FirstVueColors.ivory,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunitiesSwipePage extends StatefulWidget {
  final int refreshToken;

  const _CommunitiesSwipePage({this.refreshToken = 0});

  @override
  State<_CommunitiesSwipePage> createState() => _CommunitiesSwipePageState();
}

class _CommunitiesSwipePageState extends State<_CommunitiesSwipePage> {
  List<Community> _yours = const [];
  List<CommunityHub> _nearbyHubs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CommunitiesSwipePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      CommunityService.fetchYourCommunities(limit: 16),
      CommunityHubService.fetchNearbyHubs(limit: 12),
    ]);
    if (!mounted) return;
    setState(() {
      _yours = results[0] as List<Community>;
      _nearbyHubs = results[1] as List<CommunityHub>;
      _loading = false;
    });
  }

  Future<void> _openCreateGroup() async {
    final created = await Navigator.push<Community>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (created != null && mounted) {
      await _load();
      if (!mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => CommunityDetailScreen(
            communityId: created.id,
            initialCommunity: created,
          ),
        ),
      );
      if (mounted) await _load();
    }
  }

  Future<void> _openCreateHub() async {
    final created = await Navigator.push<CommunityHub>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityHubScreen()),
    );
    if (created != null && mounted) {
      await _load();
      if (!mounted) return;
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => CommunityHubDetailScreen(
            hubId: created.id,
            initialHub: created,
          ),
        ),
      );
      if (mounted) await _load();
    }
  }

  void _openAll() {
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const CommunitiesScreen()),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _openGroup(Community community) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CommunityDetailScreen(
          communityId: community.id,
          initialCommunity: community,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _openHub(CommunityHub hub) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CommunityHubDetailScreen(
          hubId: hub.id,
          initialHub: hub,
        ),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
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
            Text(
              'YOUR GROUPS',
              style: TextStyle(
                color: FirstVueColors.ivory.withValues(alpha: .72),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _openAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('See all', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GroupCircleRow(
          groups: _yours,
          includeCreate: true,
          emptyLabel: 'Create or join',
          onCreate: _openCreateGroup,
          onOpen: _openGroup,
          onEmptyTap: _openAll,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              'NEARBY COMMUNITIES',
              style: TextStyle(
                color: FirstVueColors.ivory.withValues(alpha: .72),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _openCreateHub,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Create', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_nearbyHubs.isEmpty)
          GestureDetector(
            onTap: _openCreateHub,
            child: const Text(
              'Local Communities will appear here. Create one if you are an approved Community Leader.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _nearbyHubs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final hub = _nearbyHubs[index];
                return GroupCircleTile(
                  label: hub.name,
                  imageUrl: hub.imageUrl,
                  ringColor: FirstVueColors.gold,
                  onTap: () => _openHub(hub),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _GroupCircleRow extends StatelessWidget {
  final List<Community> groups;
  final bool includeCreate;
  final String emptyLabel;
  final VoidCallback onCreate;
  final ValueChanged<Community> onOpen;
  final VoidCallback onEmptyTap;

  const _GroupCircleRow({
    required this.groups,
    required this.includeCreate,
    required this.emptyLabel,
    required this.onCreate,
    required this.onOpen,
    required this.onEmptyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty && !includeCreate) {
      return GestureDetector(
        onTap: onEmptyTap,
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final count = groups.length + (includeCreate ? 1 : 0);

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count == 0 ? 1 : count,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (includeCreate && index == 0) {
            return GroupCircleTile(
              label: 'Create',
              imageUrl: null,
              isCreate: true,
              onTap: onCreate,
            );
          }
          if (groups.isEmpty) {
            return GroupCircleTile(
              label: emptyLabel,
              imageUrl: null,
              onTap: onEmptyTap,
            );
          }
          final group = groups[includeCreate ? index - 1 : index];
          return GroupCircleTile(
            label: group.name,
            imageUrl: group.imageUrl,
            ringColor: group.isMember
                ? FirstVueColors.teal
                : group.isFollowing
                    ? FirstVueColors.gold
                    : Colors.white24,
            onTap: () => onOpen(group),
          );
        },
      ),
    );
  }
}

/// Public What's Now entry card (moved from main.dart private widget).
class WhatsNowEntryCard extends StatefulWidget {
  final VoidCallback onTap;

  const WhatsNowEntryCard({super.key, required this.onTap});

  @override
  State<WhatsNowEntryCard> createState() => _WhatsNowEntryCardState();
}

class _WhatsNowEntryCardState extends State<WhatsNowEntryCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? .98 : 1,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          clipBehavior: Clip.antiAlias,
          height: 168,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: pressed ? .22 : .10),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/explore_things_to_do.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: FirstVueColors.elevatedSurface),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.2, 0.55, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: .12),
                      Colors.black.withValues(alpha: .42),
                      Colors.black.withValues(alpha: .9),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: FirstVueColors.gold,
                      size: 36,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      "TRENDING & EVENTS",
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        color: FirstVueColors.ivory,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .8,
                        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'See what\'s hot and happening near you',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 12,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ],
                      ),
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

class _DiscoveryActionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DiscoveryActionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent.withValues(alpha: .95), size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: .45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
