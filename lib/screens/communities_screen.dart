import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/group_circle_avatar.dart';
import 'community_detail_screen.dart';
import 'community_hub_detail_screen.dart';
import 'create_community_hub_screen.dart';
import 'create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  /// When true (e.g. from Settings), show create FABs.
  final bool allowCreate;
  final int initialTabIndex;

  const CommunitiesScreen({
    super.key,
    this.allowCreate = false,
    this.initialTabIndex = 0,
  });

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Community> _groups = const [];
  List<CommunityHub> _hubs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 1);
    _tabs = TabController(length: 2, vsync: this, initialIndex: initial);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      CommunityService.fetchCommunities(),
      CommunityHubService.fetchHubs(),
    ]);
    if (!mounted) return;
    setState(() {
      _groups = results[0] as List<Community>;
      _hubs = results[1] as List<CommunityHub>;
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

  Future<void> _createHub() async {
    final created = await Navigator.push<CommunityHub>(
      context,
      FirstVuePageRoute(builder: (_) => const CreateCommunityHubScreen()),
    );
    if (created == null || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: null,
        title: const Text('GROUPS & COMMUNITIES'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: FirstVueColors.gold,
          unselectedLabelColor: Color(0xFF5A5668),
          indicatorColor: FirstVueColors.teal,
          tabs: const [
            Tab(text: 'GROUPS'),
            Tab(text: 'COMMUNITIES'),
          ],
        ),
      ),
      floatingActionButton: widget.allowCreate
          ? AnimatedBuilder(
              animation: _tabs,
              builder: (context, _) {
                final isGroups = _tabs.index == 0;
                return FloatingActionButton.extended(
                  onPressed: isGroups ? _createGroup : _createHub,
                  backgroundColor: FirstVueColors.coral,
                  foregroundColor: null,
                  icon: const Icon(Icons.add),
                  label: Text(isGroups ? 'Create Group' : 'Create Community'),
                );
              },
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                FirstVueRefreshScaffold(
                  onRefresh: _load,
                  child: _groups.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const Text(
                              'No groups yet.',
                              style: TextStyle(color: Color(0xFF5A5668)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.allowCreate
                                  ? 'Tap Create Group to connect with people nearby.'
                                  : 'Create from Settings → Groups & Communities.',
                              style: const TextStyle(
                                color: Color(0xFF8A8696),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: _groups.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final community = _groups[index];
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
                FirstVueRefreshScaffold(
                  onRefresh: _load,
                  child: _hubs.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const Text(
                              'No Communities yet.',
                              style: TextStyle(color: Color(0xFF5A5668)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.allowCreate
                                  ? 'Approved Community Leaders can create local hubs that contain many Groups.'
                                  : 'Create from Settings → Groups & Communities.',
                              style: const TextStyle(
                                color: Color(0xFF8A8696),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: _hubs.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final hub = _hubs[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              leading: GroupCircleAvatar(
                                imageUrl: hub.imageUrl,
                                size: 52,
                                ringColor: FirstVueColors.gold,
                                fallbackIcon: Icons.location_city_rounded,
                              ),
                              title: Text(
                                hub.name,
                                style: const TextStyle(
                                  color: Color(0xFF16131F),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                hub.locationLabel ?? 'Community hub',
                                style: const TextStyle(color: Color(0xFF5A5668)),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF8A8696),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  FirstVuePageRoute(
                                    builder: (_) => CommunityHubDetailScreen(
                                      hubId: hub.id,
                                      initialHub: hub,
                                    ),
                                  ),
                                ).then((_) => _load());
                              },
                            );
                          },
                        ),
                ),
              ],
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
              GroupCircleAvatar(
                imageUrl: community.imageUrl,
                size: 52,
                ringColor: community.isMember
                    ? FirstVueColors.teal
                    : Colors.white24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: const TextStyle(
                        color: Color(0xFF16131F),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (community.isPrivate) 'Private',
                        community.locationLabel ??
                            '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                      ].join(' · '),
                      style: const TextStyle(color: Color(0xFF5A5668), fontSize: 12),
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
              const Icon(Icons.chevron_right, color: Color(0xFF8A8696)),
            ],
          ),
        ),
      ),
    );
  }
}
