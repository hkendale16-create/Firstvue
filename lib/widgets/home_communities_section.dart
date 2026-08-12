import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';

class HomeCommunitiesSection extends StatefulWidget {
  final int refreshToken;

  const HomeCommunitiesSection({super.key, this.refreshToken = 0});

  @override
  State<HomeCommunitiesSection> createState() => _HomeCommunitiesSectionState();
}

class _HomeCommunitiesSectionState extends State<HomeCommunitiesSection> {
  List<Community> _yourCommunities = const [];
  List<Community> _nearbyCommunities = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeCommunitiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final yours = await CommunityService.fetchMyCommunities(limit: 12);
    final nearby = await CommunityService.fetchNearbyCommunities(
      limit: 12,
      excludeIds: yours.map((c) => c.id).toSet(),
    );
    if (!mounted) return;
    setState(() {
      _yourCommunities = yours;
      _nearbyCommunities = nearby;
      _loading = false;
    });
  }

  void _openDiscovery({String filter = 'all'}) {
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => CommunitiesScreen(initialFilter: filter),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _openCommunity(Community community) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Your Community Groups',
          onTap: () => _openDiscovery(filter: 'yours'),
          actionLabel: 'Explore',
        ),
        const SizedBox(height: 12),
        if (_loading)
          const _CommunityCirclesSkeleton()
        else if (_yourCommunities.isEmpty)
          _EmptyCommunityHint(
            message: "You haven't joined any communities yet. Explore groups near you.",
            actionLabel: 'Explore Communities',
            onTap: () => _openDiscovery(filter: 'nearby'),
          )
        else
          _CommunityCirclesRow(
            communities: _yourCommunities,
            onTap: _openCommunity,
          ),
        const SizedBox(height: 28),
        _SectionHeader(
          title: 'Communities in Your Area',
          onTap: () => _openDiscovery(filter: 'nearby'),
          actionLabel: 'View All',
        ),
        const SizedBox(height: 12),
        if (_loading)
          const _CommunityCirclesSkeleton()
        else if (_nearbyCommunities.isEmpty)
          _EmptyCommunityHint(
            message: 'No nearby groups yet. Search or create one.',
            actionLabel: 'Explore Communities',
            onTap: () => _openDiscovery(),
          )
        else
          _CommunityCirclesRow(
            communities: _nearbyCommunities,
            onTap: _openCommunity,
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: FirstVueColors.ivory,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: FirstVueColors.teal,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EmptyCommunityHint extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  const _EmptyCommunityHint({
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FirstVueColors.teal.withValues(alpha: .45),
                    width: 2,
                  ),
                  color: FirstVueColors.elevatedSurface,
                ),
                child: const Icon(Icons.add, color: FirstVueColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .55),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      actionLabel,
                      style: const TextStyle(
                        color: FirstVueColors.teal,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
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

class _CommunityCirclesSkeleton extends StatelessWidget {
  const _CommunityCirclesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          return SizedBox(
            width: 78,
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FirstVueColors.elevatedSurface.withValues(alpha: .9),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommunityCirclesRow extends StatelessWidget {
  final List<Community> communities;
  final ValueChanged<Community> onTap;

  const _CommunityCirclesRow({
    required this.communities,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: communities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final community = communities[index];
          return _CommunityStoryCircle(
            key: ValueKey('community-circle-${community.id}'),
            community: community,
            onTap: () => onTap(community),
          );
        },
      ),
    );
  }
}

class _CommunityStoryCircle extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;

  const _CommunityStoryCircle({
    super.key,
    required this.community,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = community.isMember || community.isCreator
        ? FirstVueColors.teal
        : community.isPending
            ? FirstVueColors.gold
            : FirstVueColors.coral.withValues(alpha: .75);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ringColor,
                    ringColor.withValues(alpha: .35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FirstVueColors.background,
                  border: Border.all(
                    color: FirstVueColors.background,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: community.imageUrl != null &&
                        community.imageUrl!.trim().isNotEmpty
                    ? Image.network(
                        community.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackAvatar(),
                      )
                    : _fallbackAvatar(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              community.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              community.isPending
                  ? 'Requested'
                  : community.isMember || community.isCreator
                      ? 'Joined'
                      : (community.locationLabel ??
                          '${community.memberCount}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return ColoredBox(
      color: FirstVueColors.elevatedSurface,
      child: Icon(
        Icons.groups_rounded,
        color: FirstVueColors.teal.withValues(alpha: .9),
        size: 28,
      ),
    );
  }
}
