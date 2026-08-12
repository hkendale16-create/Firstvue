import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/create_community_screen.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import 'group_circle_avatar.dart';

/// Home discovery: Groups first, then Communities below.
///
/// Today both rows read from `public.communities` (Groups). The Communities
/// row is the local discovery surface placed under Groups as requested.
class HomeCommunitiesSection extends StatefulWidget {
  final int refreshToken;

  const HomeCommunitiesSection({super.key, this.refreshToken = 0});

  @override
  State<HomeCommunitiesSection> createState() => _HomeCommunitiesSectionState();
}

class _HomeCommunitiesSectionState extends State<HomeCommunitiesSection> {
  List<Community> _yourGroups = const [];
  List<Community> _communitiesNearby = const [];
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
    ]);
    if (!mounted) return;
    setState(() {
      _yourGroups = results[0];
      _communitiesNearby = results[1];
      _loading = false;
    });
  }

  Future<void> _openCreateGroup() async {
    final created = await Navigator.push<bool>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (created == true && mounted) await _load();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR GROUPS',
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
          _CircleRow(
            items: _yourGroups,
            includeCreate: true,
            emptyLabel: 'Create or join a group',
            onCreate: _openCreateGroup,
            onOpen: _openGroup,
            onEmptyTap: _openAll,
          ),
        const SizedBox(height: 28),
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
              onPressed: _openAll,
              child: const Text('Explore'),
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
          _CircleRow(
            items: _communitiesNearby,
            includeCreate: false,
            emptyLabel: 'Local communities will appear here',
            onCreate: _openCreateGroup,
            onOpen: _openGroup,
            onEmptyTap: _openAll,
            defaultRingColor: FirstVueColors.gold,
          ),
      ],
    );
  }
}

class _CircleRow extends StatelessWidget {
  final List<Community> items;
  final bool includeCreate;
  final String emptyLabel;
  final VoidCallback onCreate;
  final ValueChanged<Community> onOpen;
  final VoidCallback onEmptyTap;
  final Color defaultRingColor;

  const _CircleRow({
    required this.items,
    required this.includeCreate,
    required this.emptyLabel,
    required this.onCreate,
    required this.onOpen,
    required this.onEmptyTap,
    this.defaultRingColor = Colors.white24,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !includeCreate) {
      return GestureDetector(
        onTap: onEmptyTap,
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final count = items.length + (includeCreate ? 1 : 0);

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
          if (items.isEmpty) {
            return GroupCircleTile(
              label: emptyLabel,
              imageUrl: null,
              onTap: onEmptyTap,
            );
          }
          final item = items[includeCreate ? index - 1 : index];
          return GroupCircleTile(
            label: item.name,
            imageUrl: item.imageUrl,
            ringColor: item.isMember
                ? FirstVueColors.teal
                : item.isFollowing
                    ? FirstVueColors.gold
                    : defaultRingColor,
            onTap: () => onOpen(item),
          );
        },
      ),
    );
  }
}
