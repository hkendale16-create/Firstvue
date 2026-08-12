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
  List<Community> _communities = const [];
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
    final items = await CommunityService.fetchHomePreview(limit: 8);
    if (!mounted) return;
    setState(() {
      _communities = items;
      _loading = false;
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
              onPressed: () {
                Navigator.push(
                  context,
                  FirstVuePageRoute(builder: (_) => const CommunitiesScreen()),
                );
              },
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_communities.isEmpty)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  FirstVuePageRoute(builder: (_) => const CommunitiesScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FirstVueColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: const Text(
                  'Join or create a community group',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _communities.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _CreateGroupCard(
                        onTap: () async {
                          final navigator = Navigator.of(this.context);
                          final created = await navigator.push<Community>(
                            FirstVuePageRoute(
                              builder: (_) => const CreateCommunityScreen(),
                            ),
                          );
                          if (created == null || !mounted) return;
                          await _load();
                          if (!mounted) return;
                          await navigator.push(
                            FirstVuePageRoute(
                              builder: (_) => CommunityDetailScreen(
                                communityId: created.id,
                                initialCommunity: created,
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                      );
                    }
                    final community = _communities[index - 1];
                    return _CommunityPreviewCard(
                      community: community,
                      onTap: () {
                        Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => CommunityDetailScreen(
                              communityId: community.id,
                              initialCommunity: community,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CreateGroupCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateGroupCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: FirstVueColors.coral.withValues(alpha: .45),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: FirstVueColors.coral,
                size: 24,
              ),
              Spacer(),
              Text(
                'Create group',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Start another',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityPreviewCard extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;

  const _CommunityPreviewCard({
    required this.community,
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
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: community.isMember
                  ? FirstVueColors.teal.withValues(alpha: .45)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.groups_rounded,
                color: FirstVueColors.teal.withValues(alpha: .9),
                size: 24,
              ),
              const Spacer(),
              Text(
                community.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                community.locationLabel ??
                    '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
