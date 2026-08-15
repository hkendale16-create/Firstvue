import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../auth/ensure_signed_in.dart';
import '../services/community_editor_service.dart';
import '../services/community_hub_service.dart';
import '../services/community_news_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/group_circle_avatar.dart';
import '../widgets/network_photo.dart';
import '../widgets/profile_search_picker.dart';
import 'community_detail_screen.dart';
import 'create_community_screen.dart';
import 'create_post_screen.dart';
import 'community_hub_settings_screen.dart';
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
  static const _maxEditors = 6;

  CommunityHub? _hub;
  CommunityHubLeader? _leader;
  List<Community> _groups = const [];
  List<CommunityGroupMembership> _memberships = const [];
  List<CommunityEditor> _editors = const [];
  List<Map<String, dynamic>> _linkRequests = const [];
  List<Map<String, dynamic>> _pendingLeaders = const [];
  List<CommunityNewsPost> _feedPosts = const [];
  Map<String, String> _feedPostIdBySource = const {};
  bool _loading = true;
  bool _isLeader = false;
  bool _isPendingLeader = false;
  bool _isAuthorized = false;
  bool _canPost = false;

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
    final editors = await CommunityHubService.fetchEditors(widget.hubId);
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isLeader =
        me != null &&
        await CommunityHubService.isActiveManager(widget.hubId, profileId: me);
    final isPendingLeader =
        !isLeader &&
        me != null &&
        await CommunityHubService.hasPendingManagement(
          widget.hubId,
          profileId: me,
        );
    final isEditor =
        me != null && editors.any((e) => e.userId == me && e.isActive);
    final isAuthorized = isLeader || isEditor;
    final canPost = isLeader ||
        (me != null &&
            editors.any(
              (e) =>
                  e.userId == me &&
                  e.isActive &&
                  e.hasPermission(CommunityEditorPermissions.manageNewsfeed),
            ));

    List<CommunityGroupMembership> memberships = const [];
    List<Community> groups = const [];
    try {
      memberships = await CommunityHubService.fetchCommunityGroups(
        widget.hubId,
        includePending: isAuthorized,
      );
      groups = [
        for (final m in memberships)
          if (m.group != null && m.isApproved) m.group!,
      ];
    } catch (_) {
      memberships = const [];
    }
    if (groups.isEmpty) {
      groups = await CommunityService.fetchGroupsForHub(widget.hubId);
    }

    final requests = isLeader
        ? await CommunityHubService.fetchPendingLinkRequests(widget.hubId)
        : const <Map<String, dynamic>>[];
    final pendingLeaders = isLeader
        ? await CommunityHubService.fetchPendingHubRoles(widget.hubId)
        : const <Map<String, dynamic>>[];

    final feedPosts = await CommunityNewsService.fetchHubCommunityFeed(
      widget.hubId,
    );
    final feedRefs = await CommunityHubService.fetchCommunityFeedPosts(
      widget.hubId,
    );
    final feedPostIdBySource = <String, String>{
      for (final ref in feedRefs) ref.sourcePostId: ref.id,
    };

    if (!mounted) return;
    setState(() {
      _hub = hub ?? _hub;
      _leader = leader;
      _editors = editors;
      _groups = groups;
      _memberships = memberships;
      _linkRequests = requests;
      _pendingLeaders = pendingLeaders;
      _feedPosts = feedPosts;
      _feedPostIdBySource = feedPostIdBySource;
      _isLeader = isLeader;
      _isPendingLeader = isPendingLeader;
      _isAuthorized = isAuthorized;
      _canPost = canPost;
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

  Future<void> _addExistingGroup() async {
    if (!_isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Community leaders or editors can add groups.'),
        ),
      );
      return;
    }

    final yours = await CommunityService.fetchYourCommunities(limit: 60);
    final linkedIds = {
      for (final m in _memberships)
        if (m.status != 'removed') m.groupId,
      for (final g in _groups) g.id,
    };
    final eligible = yours.where((g) => !linkedIds.contains(g.id)).toList();

    if (!mounted) return;
    if (eligible.isEmpty) {
      final create = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: context.fv.surface,
            title: Text(
              'No eligible groups',
              style: TextStyle(color: context.fv.primaryText),
            ),
            content: Text(
              'You have no groups available to add. Create a group first, then add it here.',
              style: TextStyle(color: context.fv.secondaryText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create group'),
              ),
            ],
          );
        },
      );
      if (create == true && mounted) await _createGroup();
      return;
    }

    final selected = await showModalBottomSheet<Community>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.fv.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Add existing group',
                    style: TextStyle(
                      color: context.fv.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Select a group you lead or joined. Duplicate links are blocked.',
                    style: TextStyle(color: context.fv.secondaryText, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: eligible.length,
                    separatorBuilder: (_, _) => Divider(color: context.fv.divider),
                    itemBuilder: (context, index) {
                      final group = eligible[index];
                      return ListTile(
                        leading: GroupCircleAvatar(
                          imageUrl: group.imageUrl,
                          size: 44,
                        ),
                        title: Text(
                          group.name,
                          style: TextStyle(
                            color: context.fv.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          group.category?.trim().isNotEmpty == true
                              ? group.category!
                              : (group.isMember ? 'Joined' : 'Yours'),
                          style: TextStyle(color: context.fv.tertiaryText),
                        ),
                        onTap: () => Navigator.pop(context, group),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    try {
      final membership = await CommunityHubService.addGroupToCommunity(
        hubId: widget.hubId,
        groupId: selected.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Group added (${membership.status.replaceAll('_', ' ')}).',
          ),
        ),
      );
      await _load();
    } catch (_) {
      // Fall back to request flow when direct add is not permitted.
      try {
        final pending = await CommunityHubService.requestGroupJoin(
          hubId: widget.hubId,
          groupId: selected.id,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request submitted (${pending.status}). Awaiting approval.',
            ),
          ),
        );
        await _load();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add group. Try again.')),
        );
      }
    }
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

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _feedPosts.length) return;
    final post = _feedPosts[index];
    final previous = post;
    final optimistic = post.copyWith(
      sparkedByMe: !post.sparkedByMe,
      sparkCount: post.sparkCount + (post.sparkedByMe ? -1 : 1),
    );
    setState(() {
      _feedPosts = [
        for (var i = 0; i < _feedPosts.length; i++)
          if (i == index) optimistic else _feedPosts[i],
      ];
    });
    try {
      final updated = await CommunityNewsService.toggleSpark(post);
      if (!mounted) return;
      setState(() {
        _feedPosts = [
          for (var i = 0; i < _feedPosts.length; i++)
            if (i == index) updated else _feedPosts[i],
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedPosts = [
          for (var i = 0; i < _feedPosts.length; i++)
            if (i == index) previous else _feedPosts[i],
        ];
      });
    }
  }

  Future<void> _savePost(int index) async {
    if (index < 0 || index >= _feedPosts.length) return;
    final post = _feedPosts[index];
    final previous = post;
    final optimistic = post.copyWith(savedByMe: !post.savedByMe);
    setState(() {
      _feedPosts = [
        for (var i = 0; i < _feedPosts.length; i++)
          if (i == index) optimistic else _feedPosts[i],
      ];
    });
    try {
      final updated = await CommunityNewsService.toggleSave(post);
      if (!mounted) return;
      setState(() {
        _feedPosts = [
          for (var i = 0; i < _feedPosts.length; i++)
            if (i == index) updated else _feedPosts[i],
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedPosts = [
          for (var i = 0; i < _feedPosts.length; i++)
            if (i == index) previous else _feedPosts[i],
        ];
      });
    }
  }

  Future<void> _softRemoveFeedPost(CommunityNewsPost post) async {
    final feedPostId = _feedPostIdBySource[post.id];
    if (feedPostId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to remove this post from the feed.'),
        ),
      );
      return;
    }
    try {
      await CommunityHubService.softRemoveFeedPost(feedPostId);
      if (!mounted) return;
      setState(() {
        _feedPosts = [
          for (final p in _feedPosts)
            if (p.id != post.id) p,
        ];
        _feedPostIdBySource = {
          for (final e in _feedPostIdBySource.entries)
            if (e.key != post.id) e.key: e.value,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post removed from Community feed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove post. Try again.')),
      );
    }
  }

  Future<void> _composeHubPost() async {
    if (!_canPost) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) return;
    }
    try {
      final groupId = await CommunityHubService.ensureNewsfeedGroup(
        widget.hubId,
      );
      if (!mounted) return;
      final created = await Navigator.push<CommunityNewsPost>(
        context,
        FirstVuePageRoute(
          builder: (_) => CreatePostScreen(
            communityId: groupId,
            lockIdentity: true,
          ),
        ),
      );
      if (created != null && mounted) await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? error.message
                : 'Could not open Community composer. Apply the Community '
                    'owner posting SQL if this persists.',
          ),
        ),
      );
    }
  }

  Future<void> _showAddEditorDialog() async {
    if (_editors.where((e) => e.isActive).length >= _maxEditors) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Up to 6 Editors allowed.')));
      return;
    }

    final picked = await ProfileSearchPicker.show(
      context,
      title: 'Add Community Editor',
      subtitle: 'Up to 6 editors. Search by name or @username.',
    );
    if (picked == null || !mounted) return;

    try {
      final permissions = {
        for (final key in CommunityEditorPermissions.allKeys) key: true,
      };
      await CommunityEditorService.addEditor(
        widget.hubId,
        picked.id,
        permissions,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${picked.displayName} as Editor.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? error.message
                : 'Could not add editor. Try again.',
          ),
        ),
      );
    }
  }

  Future<void> _showAddLeaderDialog() async {
    final picked = await ProfileSearchPicker.show(
      context,
      title: 'Invite Community Leader',
      subtitle: 'Search profiles. Selecting stores their profile ID.',
    );
    if (picked == null || !mounted) return;

    try {
      await CommunityHubService.inviteHubLeader(
        hubId: widget.hubId,
        profileId: picked.id,
        role: 'leader',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invited ${picked.displayName}. They appear under pending until approved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? error.message
                : 'Could not invite leader. Try again.',
          ),
        ),
      );
    }
  }

  Future<void> _removeEditor(CommunityEditor editor) async {
    try {
      await CommunityEditorService.removeEditor(editor.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not remove editor.')));
    }
  }

  Future<void> _setGroupFeedPosting({
    required String groupId,
    required bool allow,
  }) async {
    try {
      await CommunityHubService.setGroupFeedPosting(
        hubId: widget.hubId,
        groupId: groupId,
        allow: allow,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update posting permission.')),
      );
    }
  }

  Future<void> _removeGroup(String groupId) async {
    try {
      await CommunityHubService.removeGroupFromCommunity(
        hubId: widget.hubId,
        groupId: groupId,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not remove group.')));
    }
  }

  String _statusLabel(CommunityGroupMembership m) {
    if (m.isApprovedForFeed || m.canPostToCommunityFeed) {
      return 'Can post';
    }
    if (m.isApproved) return 'Approved';
    if (m.isPending) return 'Pending';
    return m.status;
  }

  Color _statusColor(CommunityGroupMembership m) {
    if (m.isApprovedForFeed || m.canPostToCommunityFeed) {
      return FirstVueColors.teal;
    }
    if (m.isApproved) return FirstVueColors.gold;
    if (m.isPending) return Colors.orangeAccent;
    return const Color(0xFF5A5668);
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: FirstVueColors.gold,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  List<CommunityGroupMembership> get _displayMemberships {
    if (_memberships.isNotEmpty) {
      if (_isAuthorized) {
        return _memberships
            .where((m) => m.status != 'removed' && m.status != 'denied')
            .toList();
      }
      return _memberships.where((m) => m.isApproved).toList();
    }
    return [
      for (final g in _groups)
        CommunityGroupMembership(
          id: g.id,
          communityId: widget.hubId,
          groupId: g.id,
          status: 'approved',
          createdAt: g.createdAt,
          group: g,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hub = _hub;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: null,
        title: Text(hub?.name ?? 'Community'),
        actions: [
          if (_isAuthorized)
            IconButton(
              tooltip: 'Community settings',
              onPressed: () async {
                final hub = _hub;
                if (hub == null) return;
                await Navigator.push(
                  context,
                  FirstVuePageRoute(
                    builder: (_) => CommunityHubSettingsScreen(
                      hubId: widget.hubId,
                      initialHub: hub,
                    ),
                  ),
                );
                if (mounted) await _load();
              },
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(
            onPressed: hub == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      floatingActionButton: (_isAuthorized || _canPost)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_canPost) ...[
                  FloatingActionButton.extended(
                    heroTag: 'hub-post',
                    onPressed: _composeHubPost,
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Post'),
                  ),
                  if (_isAuthorized) const SizedBox(height: 10),
                ],
                if (_isAuthorized)
                  FloatingActionButton.extended(
                    heroTag: 'hub-add-group',
                    onPressed: _addExistingGroup,
                    backgroundColor: FirstVueColors.coral,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Add Group'),
                  ),
              ],
            )
          : null,
      body: _loading && hub == null
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : hub == null
          ? Center(
              child: Text(
                'Community not found.',
                style: TextStyle(color: context.fv.secondaryText),
              ),
            )
          : FirstVueRefreshScaffold(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  if (_isPendingLeader) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: FirstVueColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Your Community management role is still pending. '
                        'If you created this Community, ask a FirstVue admin '
                        'to apply the owner-posting SQL so your creator role '
                        'activates automatically.',
                        style: TextStyle(
                          color: FirstVueColors.gold,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      GroupCircleAvatar(
                        imageUrl: hub.coverUrl ?? hub.imageUrl,
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
                              style: TextStyle(
                        color: context.fv.primaryText,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hub.category?.trim().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  hub.category!.trim(),
                                  style: const TextStyle(
                                    color: FirstVueColors.teal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (hub.locationLabel != null)
                              Text(
                                hub.locationLabel!,
                                style: TextStyle(
                        color: context.fv.secondaryText,
                                ),
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
                          NetworkCircleAvatar(
                            imageUrl: _leader!.avatarUrl,
                            radius: 18,
                            backgroundColor: FirstVueColors.elevatedSurface,
                            placeholder: Text(
                              _leader!.displayName.isNotEmpty
                                  ? _leader!.displayName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _leader!.displayName,
                                  style: TextStyle(
                        color: context.fv.primaryText,
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
                  const SizedBox(height: 24),
                  _sectionTitle('ABOUT'),
                  const SizedBox(height: 8),
                  if (hub.description?.trim().isNotEmpty == true)
                    Text(
                      hub.description!.trim(),
                      style: TextStyle(
                        color: context.fv.secondaryText,
                        height: 1.4,
                      ),
                    )
                  else
                    Text(
                      'No description yet.',
                      style: TextStyle(color: context.fv.secondaryText),
                    ),
                  if (hub.rules?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Rules',
                      style: TextStyle(
                        color: context.fv.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hub.rules!.trim(),
                      style: TextStyle(
                        color: context.fv.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('COMMUNITY EDITORS')),
                      Text(
                        'Up to 6 Editors',
                        style: TextStyle(
                          color: context.fv.tertiaryText,
                          fontSize: 11,
                        ),
                      ),
                      if (_isLeader) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _showAddLeaderDialog,
                          icon: const Icon(
                            Icons.workspace_premium_outlined,
                            color: FirstVueColors.gold,
                            size: 20,
                          ),
                          tooltip: 'Invite leader',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: _showAddEditorDialog,
                          icon: const Icon(
                            Icons.person_add_alt_1,
                            color: FirstVueColors.teal,
                            size: 20,
                          ),
                          tooltip: 'Add editor',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_editors.isEmpty)
                    Text(
                      'No editors appointed yet.',
                      style: TextStyle(color: context.fv.secondaryText),
                    )
                  else
                    ..._editors.map((editor) {
                      final label =
                          editor.displayName?.trim().isNotEmpty == true
                          ? editor.displayName!
                          : (editor.username != null
                                ? '@${editor.username}'
                                : editor.userId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: NetworkCircleAvatar(
                          imageUrl: editor.avatarUrl,
                          radius: 18,
                          backgroundColor: FirstVueColors.elevatedSurface,
                          placeholder: Text(
                            label.isNotEmpty
                                ? label[0].toUpperCase()
                                : 'E',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          label,
                          style: TextStyle(color: context.fv.primaryText),
                        ),
                        subtitle: editor.username != null
                            ? Text(
                                '@${editor.username}',
                                style: TextStyle(
                        color: context.fv.secondaryText,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: _isLeader
                            ? IconButton(
                                onPressed: () => _removeEditor(editor),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: FirstVueColors.coral,
                                  size: 20,
                                ),
                                tooltip: 'Remove editor',
                              )
                            : null,
                        onTap: () => openMemberProfile(
                          context,
                          profileId: editor.userId,
                          displayName: label,
                        ),
                      );
                    }),
                  if (_pendingLeaders.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionTitle('PENDING LEADERS'),
                    ..._pendingLeaders.map((req) {
                      final profile = req['profiles'] as Map<String, dynamic>?;
                      final name =
                          (profile?['display_name'] as String?) ?? 'Member';
                      final profileId = req['profile_id'] as String;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: TextStyle(color: context.fv.primaryText),
                        ),
                        subtitle: Text(
                          (req['role'] as String?) ?? 'leader',
                          style: TextStyle(color: context.fv.secondaryText),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await CommunityHubService.reviewHubRole(
                                  hubId: widget.hubId,
                                  profileId: profileId,
                                  approve: true,
                                );
                                await _load();
                              },
                              child: const Text('Approve'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await CommunityHubService.reviewHubRole(
                                  hubId: widget.hubId,
                                  profileId: profileId,
                                  approve: false,
                                );
                                await _load();
                              },
                              child: const Text(
                                'Decline',
                                style: TextStyle(color: FirstVueColors.coral),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_linkRequests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _sectionTitle('GROUP LINK REQUESTS'),
                    ..._linkRequests.map((req) {
                      final group = req['communities'] as Map<String, dynamic>?;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GroupCircleAvatar(
                          imageUrl: group?['image_url'] as String?,
                          size: 44,
                        ),
                        title: Text(
                          (group?['name'] as String?) ?? 'Group',
                          style: TextStyle(color: context.fv.primaryText),
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
                                style: TextStyle(color: FirstVueColors.coral),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 28),
                  _sectionTitle('GROUPS'),
                  const SizedBox(height: 12),
                  if (_displayMemberships.isEmpty)
                    Text(
                      'No groups linked yet. Create one to get started.',
                      style: TextStyle(color: context.fv.secondaryText),
                    )
                  else
                    ..._displayMemberships.map((membership) {
                      final group = membership.group;
                      final name = group?.name ?? 'Group';
                      final imageUrl = group?.imageUrl;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: GroupCircleAvatar(
                                imageUrl: imageUrl,
                                size: 48,
                                ringColor: membership.canPostToCommunityFeed
                                    ? FirstVueColors.teal
                                    : context.fv.borderSubtle,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                        color: context.fv.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      membership,
                                    ).withValues(alpha: .18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _statusColor(
                                        membership,
                                      ).withValues(alpha: .45),
                                    ),
                                  ),
                                  child: Text(
                                    _statusLabel(membership),
                                    style: TextStyle(
                                      color: _statusColor(membership),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              onTap: group == null
                                  ? null
                                  : () {
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
                            ),
                            if (_isAuthorized && membership.isApproved)
                              Padding(
                                padding: const EdgeInsets.only(left: 56),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (!membership.canPostToCommunityFeed &&
                                        !membership.isApprovedForFeed)
                                      TextButton(
                                        onPressed: () => _setGroupFeedPosting(
                                          groupId: membership.groupId,
                                          allow: true,
                                        ),
                                        child: const Text(
                                          'Approve posting',
                                          style: TextStyle(
                                            color: FirstVueColors.teal,
                                          ),
                                        ),
                                      ),
                                    if (membership.canPostToCommunityFeed ||
                                        membership.isApprovedForFeed)
                                      TextButton(
                                        onPressed: () => _setGroupFeedPosting(
                                          groupId: membership.groupId,
                                          allow: false,
                                        ),
                                        child: const Text(
                                          'Revoke posting',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                      ),
                                    TextButton(
                                      onPressed: () =>
                                          _removeGroup(membership.groupId),
                                      child: const Text(
                                        'Remove group',
                                        style: TextStyle(
                                          color: FirstVueColors.coral,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_isAuthorized && membership.isPending)
                              Padding(
                                padding: const EdgeInsets.only(left: 56),
                                child: Row(
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        await CommunityHubService.reviewGroupMembership(
                                          hubId: widget.hubId,
                                          groupId: membership.groupId,
                                          approve: true,
                                        );
                                        await _load();
                                      },
                                      child: const Text('Approve'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await CommunityHubService.reviewGroupMembership(
                                          hubId: widget.hubId,
                                          groupId: membership.groupId,
                                          approve: false,
                                        );
                                        await _load();
                                      },
                                      child: const Text(
                                        'Deny',
                                        style: TextStyle(
                                          color: FirstVueColors.coral,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 28),
                  _sectionTitle('COMMUNITY NEWSFEED'),
                  const SizedBox(height: 8),
                  Text(
                    _canPost
                        ? 'Owners, leaders, and permitted editors can post here. Linked Groups also publish into this feed.'
                        : 'Posts from authorized Community roles and linked Groups appear here.',
                    style: TextStyle(
                      color: context.fv.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  if (_canPost) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _composeHubPost,
                        style: FilledButton.styleFrom(
                          backgroundColor: FirstVueColors.gold,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Create post'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_loading && _feedPosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: FirstVueColors.teal,
                        ),
                      ),
                    )
                  else if (_feedPosts.isEmpty)
                    Text(
                      _canPost
                          ? 'No community posts yet. Create the first one.'
                          : 'No community posts yet.',
                      style: TextStyle(color: context.fv.secondaryText),
                    )
                  else
                    Column(
                      children: [
                        for (
                          var index = 0;
                          index < _feedPosts.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 10),
                          CommunityNewsPostCard(
                            post: _feedPosts[index],
                            style: CommunityNewsPostCardStyle.timeline,
                            onTap: () => CommunityNewsPostDetailSheet.show(
                              context,
                              postId: _feedPosts[index].id,
                              initialPost: _feedPosts[index],
                            ),
                            onAuthorTap: _feedPosts[index].authorId.isNotEmpty
                                ? () => openMemberProfile(
                                    context,
                                    profileId: _feedPosts[index].authorId,
                                    displayName: _feedPosts[index].authorName,
                                  )
                                : null,
                            onSpark: () => _sparkPost(index),
                            onSave: () => _savePost(index),
                            onComment: () => FeedCommentsSheet.show(
                              context,
                              mediaId: _feedPosts[index].commentsMediaId,
                              businessName: _feedPosts[index].authorName,
                            ),
                            onDelete:
                                _isLeader &&
                                    _feedPostIdBySource.containsKey(
                                      _feedPosts[index].id,
                                    )
                                ? () => _softRemoveFeedPost(_feedPosts[index])
                                : null,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}
