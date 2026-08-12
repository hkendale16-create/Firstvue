import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/communities_screen.dart';
import '../screens/community_detail_screen.dart';
import '../screens/create_community_screen.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';

class HomeCommunitiesSection extends StatefulWidget {
  final int refreshToken;

  const HomeCommunitiesSection({super.key, this.refreshToken = 0});

  @override
  State<HomeCommunitiesSection> createState() => _HomeCommunitiesSectionState();
}

class _HomeCommunitiesSectionState extends State<HomeCommunitiesSection> {
  List<Community> _yours = const [];
  List<Community> _nearby = const [];
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
      _yours = results[0];
      _nearby = results[1];
      _loading = false;
    });
  }

  Future<void> _openCreate() async {
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

  void _openAll() {
    Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const CommunitiesScreen()),
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
          _CommunityCircleRow(
            communities: _yours,
            includeCreate: true,
            emptyLabel: 'Create or join a group',
            onCreate: _openCreate,
            onOpen: _openCommunity,
            onEmptyTap: _openAll,
          ),
        const SizedBox(height: 26),
        const Text(
          'COMMUNITIES IN YOUR AREA',
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
          _CommunityCircleRow(
            communities: _nearby,
            includeCreate: false,
            emptyLabel: 'Nearby groups will appear here',
            onCreate: _openCreate,
            onOpen: _openCommunity,
            onEmptyTap: _openAll,
          ),
      ],
    );
  }
}

class _CommunityCircleRow extends StatelessWidget {
  final List<Community> communities;
  final bool includeCreate;
  final String emptyLabel;
  final VoidCallback onCreate;
  final ValueChanged<Community> onOpen;
  final VoidCallback onEmptyTap;

  const _CommunityCircleRow({
    required this.communities,
    required this.includeCreate,
    required this.emptyLabel,
    required this.onCreate,
    required this.onOpen,
    required this.onEmptyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty && !includeCreate) {
      return GestureDetector(
        onTap: onEmptyTap,
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }

    final count = communities.length + (includeCreate ? 1 : 0);

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count == 0 ? 1 : count,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (includeCreate && index == 0) {
            return _CommunityCircle(
              label: 'Create',
              onTap: onCreate,
              isCreate: true,
              isFollowing: false,
              isMember: false,
              imageUrl: null,
            );
          }
          if (communities.isEmpty) {
            return _CommunityCircle(
              label: emptyLabel,
              onTap: onEmptyTap,
              isCreate: false,
              isFollowing: false,
              isMember: false,
              imageUrl: null,
            );
          }
          final community = communities[includeCreate ? index - 1 : index];
          return _CommunityCircle(
            label: community.name,
            imageUrl: community.imageUrl,
            isCreate: false,
            isFollowing: community.isFollowing,
            isMember: community.isMember,
            onTap: () => onOpen(community),
          );
        },
      ),
    );
  }
}

class _CommunityCircle extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isCreate;
  final bool isMember;
  final bool isFollowing;
  final VoidCallback onTap;

  const _CommunityCircle({
    required this.label,
    required this.imageUrl,
    required this.isCreate,
    required this.isMember,
    required this.isFollowing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isCreate
        ? FirstVueColors.coral
        : isMember
            ? FirstVueColors.teal
            : isFollowing
                ? FirstVueColors.gold
                : Colors.white24;

    return SizedBox(
      width: 78,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
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
                    ringColor.withValues(alpha: .95),
                    ringColor.withValues(alpha: .35),
                  ],
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF080B0F),
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: FirstVueColors.elevatedSurface,
                  backgroundImage: !isCreate &&
                          imageUrl != null &&
                          imageUrl!.trim().isNotEmpty
                      ? NetworkImage(imageUrl!)
                      : null,
                  child: isCreate
                      ? const Icon(Icons.add, color: FirstVueColors.coral)
                      : (imageUrl == null || imageUrl!.trim().isEmpty)
                          ? const Icon(
                              Icons.groups_rounded,
                              color: FirstVueColors.teal,
                            )
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
