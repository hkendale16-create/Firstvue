import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/community_hub_detail_screen.dart';
import '../screens/create_community_hub_screen.dart';
import '../screens/create_community_screen.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import 'group_circle_avatar.dart';

class HomeCommunitiesSection extends StatefulWidget {
  final int refreshToken;

  const HomeCommunitiesSection({super.key, this.refreshToken = 0});

  @override
  State<HomeCommunitiesSection> createState() => _HomeCommunitiesSectionState();
}

class _HomeCommunitiesSectionState extends State<HomeCommunitiesSection> {
  List<Community> _yours = const [];
  List<Community> _nearbyGroups = const [];
  List<CommunityHub> _nearbyHubs = const [];
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
    final results = await Future.wait([
      CommunityService.fetchYourCommunities(limit: 16),
      CommunityService.fetchNearbyCommunities(limit: 16),
      CommunityHubService.fetchNearbyHubs(limit: 12),
    ]);
    if (!mounted) return;
    setState(() {
      _yours = results[0] as List<Community>;
      _nearbyGroups = results[1] as List<Community>;
      _nearbyHubs = results[2] as List<CommunityHub>;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR COMMUNITY GROUPS',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: _openAll,
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 110,
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else
          _GroupCircleRow(
            groups: _yours,
            includeCreate: true,
            emptyLabel: 'Create or join a group',
            onCreate: _openCreateGroup,
            onOpen: _openGroup,
            onEmptyTap: _openAll,
          ),
        const SizedBox(height: 26),
        const Text(
          'GROUPS IN YOUR AREA',
          style: TextStyle(
            color: FirstVueColors.ivory,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 110,
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else
          _GroupCircleRow(
            groups: _nearbyGroups,
            includeCreate: false,
            emptyLabel: 'Nearby groups will appear here',
            onCreate: _openCreateGroup,
            onOpen: _openGroup,
            onEmptyTap: _openAll,
          ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: Text(
                'COMMUNITIES IN YOUR AREA',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: _openCreateHub,
              child: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 110,
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_nearbyHubs.isEmpty)
          GestureDetector(
            onTap: _openCreateHub,
            child: const Text(
              'Local Communities will appear here. Create one if you are an approved Community Leader.',
              style: TextStyle(color: Colors.white54),
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
