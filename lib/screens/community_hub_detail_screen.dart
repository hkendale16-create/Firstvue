import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/community_hub_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/group_circle_avatar.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';
import 'member_public_profile_screen.dart';

class CommunityHubDetailScreen extends StatefulWidget {
  final String hubId;
  final CommunityHub? initialHub;

  const CommunityHubDetailScreen({
    super.key,
    required this.hubId,
    this.initialHub,
  });

  @override
  State<CommunityHubDetailScreen> createState() =>
      _CommunityHubDetailScreenState();
}

class _CommunityHubDetailScreenState extends State<CommunityHubDetailScreen> {
  CommunityHub? _hub;
  CommunityHubLeader? _leader;
  List<Community> _groups = const [];
  List<Map<String, dynamic>> _linkRequests = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _hub = widget.initialHub;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final hub = await CommunityHubService.fetchHubById(widget.hubId);
    final leader = await CommunityHubService.fetchPrimaryLeader(widget.hubId);
    final groups = await CommunityService.fetchGroupsForHub(widget.hubId);
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isLeader = hub != null && me != null && hub.createdByProfileId == me;
    final requests = isLeader
        ? await CommunityHubService.fetchPendingLinkRequests(widget.hubId)
        : const <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _hub = hub ?? _hub;
      _leader = leader;
      _groups = groups;
      _linkRequests = requests;
      _loading = false;
    });
  }

  Future<void> _createGroup() async {
    final created = await Navigator.push<Community>(
      context,
      FirstVuePageRoute(
        builder: (_) => CreateCommunityScreen(initialHubId: widget.hubId),
      ),
    );
    if (created != null && mounted) await _load();
  }

  void _share() {
    final hub = _hub;
    if (hub == null) return;
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: hub.name,
        subtitle: hub.description ?? 'Explore this FirstVue Community',
        link: '${AppConfig.webBaseUrl}/?communityHub=${hub.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = _hub;

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: Text(hub?.name ?? 'Community'),
        actions: [
          IconButton(
            onPressed: hub == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: FirstVueColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
      ),
      body: _loading && hub == null
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : hub == null
              ? const Center(
                  child: Text(
                    'Community not found.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : FirstVueRefreshScaffold(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      Row(
                        children: [
                          GroupCircleAvatar(
                            imageUrl: hub.imageUrl,
                            size: 84,
                            ringColor: FirstVueColors.gold,
                            fallbackIcon: Icons.location_city_rounded,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hub.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (hub.locationLabel != null)
                                  Text(
                                    hub.locationLabel!,
                                    style: const TextStyle(color: Colors.white54),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_groups.length} groups',
                                  style: const TextStyle(
                                    color: FirstVueColors.gold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hub.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Text(
                          hub.description!.trim(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (_leader != null) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () => openMemberProfile(
                            context,
                            profileId: _leader!.profileId,
                            displayName: _leader!.displayName,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: FirstVueColors.elevatedSurface,
                                backgroundImage: _leader!.avatarUrl != null &&
                                        _leader!.avatarUrl!.isNotEmpty
                                    ? NetworkImage(_leader!.avatarUrl!)
                                    : null,
                                child: _leader!.avatarUrl == null ||
                                        _leader!.avatarUrl!.isEmpty
                                    ? Text(
                                        _leader!.displayName.isNotEmpty
                                            ? _leader!.displayName[0]
                                                .toUpperCase()
                                            : '?',
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _leader!.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      [
                                        if (_leader!.username != null)
                                          '@${_leader!.username}',
                                        'Community Leader',
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: FirstVueColors.teal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_linkRequests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'GROUP LINK REQUESTS',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        ..._linkRequests.map((req) {
                          final group =
                              req['communities'] as Map<String, dynamic>?;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: GroupCircleAvatar(
                              imageUrl: group?['image_url'] as String?,
                              size: 44,
                            ),
                            title: Text(
                              (group?['name'] as String?) ?? 'Group',
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await CommunityHubService.reviewLinkRequest(
                                      requestId: req['id'] as String,
                                      approve: true,
                                    );
                                    await _load();
                                  },
                                  child: const Text('Approve'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await CommunityHubService.reviewLinkRequest(
                                      requestId: req['id'] as String,
                                      approve: false,
                                    );
                                    await _load();
                                  },
                                  child: const Text(
                                    'Decline',
                                    style:
                                        TextStyle(color: FirstVueColors.coral),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 28),
                      const Text(
                        'GROUPS IN THIS COMMUNITY',
                        style: TextStyle(
                          color: FirstVueColors.gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_groups.isEmpty)
                        const Text(
                          'No groups linked yet. Create one to get started.',
                          style: TextStyle(color: Colors.white54),
                        )
                      else
                        SizedBox(
                          height: 118,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _groups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              return GroupCircleTile(
                                label: group.name,
                                imageUrl: group.imageUrl,
                                ringColor: group.isMember
                                    ? FirstVueColors.teal
                                    : Colors.white24,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    FirstVuePageRoute(
                                      builder: (_) => CommunityDetailScreen(
                                        communityId: group.id,
                                        initialCommunity: group,
                                      ),
                                    ),
                                  ).then((_) {
                                    if (mounted) _load();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      if (hub.rules?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'ABOUT / RULES',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hub.rules!.trim(),
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
