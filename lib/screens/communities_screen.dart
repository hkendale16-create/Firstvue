import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen> {
  List<Community> _communities = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await CommunityService.fetchCommunities();
    if (!mounted) return;
    setState(() {
      _communities = items;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    final created = await Navigator.push<Community>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityScreen()),
    );
    if (created == null || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: const Text('COMMUNITIES'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: FirstVueColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FirstVueColors.teal))
          : FirstVueRefreshScaffold(
              onRefresh: _load,
              child: _communities.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        Text(
                          'No groups yet. Create one to connect with your community.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: _communities.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final community = _communities[index];
                        return _CommunityListTile(
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
                            ).then((_) => _load());
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

class _CommunityListTile extends StatelessWidget {
  final Community community;
  final VoidCallback onTap;

  const _CommunityListTile({
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: FirstVueColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: FirstVueColors.teal.withValues(alpha: .9),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      community.locationLabel ??
                          '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if (community.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        community.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (community.isMember)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FirstVueColors.teal.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Joined',
                    style: TextStyle(color: FirstVueColors.teal, fontSize: 11),
                  ),
                ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
