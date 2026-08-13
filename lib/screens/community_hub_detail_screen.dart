import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
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
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _hub = widget.initialHub;
    _load();
  }

  bool _computeIsLeader(CommunityHub? hub, String? me) {
    if (hub == null || me == null) return false;
    return hub.leaderUserId == me || hub.createdByProfileId == me;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final hub = await CommunityHubService.fetchHubById(widget.hubId);
    final leader = await CommunityHubService.fetchPrimaryLeader(widget.hubId);
    final editors = await CommunityHubService.fetchEditors(widget.hubId);
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isLeader = _computeIsLeader(hub, me);
    final isEditor = me != null &&
        editors.any((e) => e.userId == me && e.isActive);
    final isAuthorized = isLeader || isEditor;

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

    final feedPosts =
        await CommunityNewsService.fetchHubCommunityFeed(widget.hubId);
    final feedRefs =
        await CommunityHubService.fetchCommunityFeedPosts(widget.hubId);
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
      _isAuthorized = isAuthorized;
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
        const SnackBar(content: Text('Unable to remove this post from the feed.')),
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

  Future<String?> _resolveProfileId(String raw) async {
    final input = raw.trim().replaceFirst(RegExp(r'^@'), '');
    if (input.isEmpty) return null;

    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidPattern.hasMatch(input)) return input;

    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .ilike('username', input)
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAddEditorDialog() async {
    if (_editors.where((e) => e.isActive).length >= _maxEditors) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Up to 6 Editors allowed.')),
      );
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10151B),
        title: const Text(
          'Add Community Editor',
          style: TextStyle(color: const Color(0xFF16131F)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Up to 6 Editors',
              style: TextStyle(color: FirstVueColors.gold, fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Color(0xFF16131F)),
              decoration: const InputDecoration(
                hintText: 'Profile UUID or username',
                hintStyle: TextStyle(color: Color(0xFF8A8696)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0x1A16131F)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: FirstVueColors.teal),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    final raw = controller.text;
    controller.dispose();
    if (confirmed != true || !mounted) return;

    final userId = await _resolveProfileId(raw);
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not found.')),
      );
      return;
    }

    try {
      final permissions = {
        for (final key in CommunityEditorPermissions.allKeys) key: true,
      };
      await CommunityEditorService.addEditor(
        widget.hubId,
        userId,
        permissions,
      );
      await _load();
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

  Future<void> _removeEditor(CommunityEditor editor) async {
    try {
      await CommunityEditorService.removeEditor(editor.id);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove editor.')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove group.')),
      );
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
          IconButton(
            onPressed: hub == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: FirstVueColors.coral,
        foregroundColor: null,
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
                    style: TextStyle(color: Color(0xFF5A5668)),
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
                                  style: const TextStyle(
                                    color: const Color(0xFF16131F),
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
                                    style: const TextStyle(color: Color(0xFF5A5668)),
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
                                        color: const Color(0xFF16131F),
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
                            color: Colors.white.withValues(alpha: .78),
                            height: 1.4,
                          ),
                        )
                      else
                        const Text(
                          'No description yet.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        ),
                      if (hub.rules?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Rules',
                          style: TextStyle(
                            color: Color(0xFF5A5668),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hub.rules!.trim(),
                          style: const TextStyle(
                            color: Color(0xFF5A5668),
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
                              color: Colors.white.withValues(alpha: .45),
                              fontSize: 11,
                            ),
                          ),
                          if (_isLeader) ...[
                            const SizedBox(width: 4),
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
                        const Text(
                          'No editors appointed yet.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        )
                      else
                        ..._editors.map((editor) {
                          final label = editor.displayName?.trim().isNotEmpty ==
                                  true
                              ? editor.displayName!
                              : (editor.username != null
                                  ? '@${editor.username}'
                                  : editor.userId);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: FirstVueColors.elevatedSurface,
                              backgroundImage: editor.avatarUrl != null &&
                                      editor.avatarUrl!.isNotEmpty
                                  ? NetworkImage(editor.avatarUrl!)
                                  : null,
                              child: editor.avatarUrl == null ||
                                      editor.avatarUrl!.isEmpty
                                  ? Text(
                                      label.isNotEmpty
                                          ? label[0].toUpperCase()
                                          : 'E',
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : null,
                            ),
                            title: Text(
                              label,
                              style: const TextStyle(color: Color(0xFF16131F)),
                            ),
                            subtitle: editor.username != null
                                ? Text(
                                    '@${editor.username}',
                                    style: const TextStyle(
                                      color: Color(0xFF5A5668),
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
                          final profile =
                              req['profiles'] as Map<String, dynamic>?;
                          final name =
                              (profile?['display_name'] as String?) ??
                              'Member';
                          final profileId = req['profile_id'] as String;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              name,
                              style: const TextStyle(color: Color(0xFF16131F)),
                            ),
                            subtitle: Text(
                              (req['role'] as String?) ?? 'leader',
                              style: const TextStyle(color: Color(0xFF5A5668)),
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
                                    style:
                                        TextStyle(color: FirstVueColors.coral),
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
                              style: const TextStyle(color: Color(0xFF16131F)),
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
                      _sectionTitle('GROUPS'),
                      const SizedBox(height: 12),
                      if (_displayMemberships.isEmpty)
                        const Text(
                          'No groups linked yet. Create one to get started.',
                          style: TextStyle(color: Color(0xFF5A5668)),
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
                                        : Colors.white24,
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      color: const Color(0xFF16131F),
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
                                        color: _statusColor(membership)
                                            .withValues(alpha: .18),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _statusColor(membership)
                                              .withValues(alpha: .45),
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
                                              builder: (_) =>
                                                  CommunityDetailScreen(
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
                                            onPressed: () =>
                                                _setGroupFeedPosting(
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
                                            onPressed: () =>
                                                _setGroupFeedPosting(
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
                                            await CommunityHubService
                                                .reviewGroupMembership(
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
                                            await CommunityHubService
                                                .reviewGroupMembership(
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
                      const Text(
                        'Groups publish into this feed.',
                        style: TextStyle(color: Color(0xFF5A5668), fontSize: 12),
                      ),
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
                        const Text(
                          'No community posts yet.',
                          style: TextStyle(color: Color(0xFF5A5668)),
                        )
                      else
                        Column(
                          children: [
                            for (var index = 0;
                                index < _feedPosts.length;
                                index++) ...[
                              if (index > 0) const SizedBox(height: 10),
                              CommunityNewsPostCard(
                                post: _feedPosts[index],
                                style: CommunityNewsPostCardStyle.timeline,
                                onTap: () => CommunityNewsPostDetailSheet.show(
                                  context,
                                  postId: _feedPosts[index].id,
                                  initialPost: _feedPosts[index],
                                ),
                                onAuthorTap:
                                    _feedPosts[index].authorId.isNotEmpty
                                        ? () => openMemberProfile(
                                              context,
                                              profileId:
                                                  _feedPosts[index].authorId,
                                              displayName:
                                                  _feedPosts[index].authorName,
                                            )
                                        : null,
                                onSpark: () => _sparkPost(index),
                                onSave: () => _savePost(index),
                                onComment: () => FeedCommentsSheet.show(
                                  context,
                                  mediaId: _feedPosts[index].commentsMediaId,
                                  businessName: _feedPosts[index].authorName,
                                ),
                                onDelete: _isLeader &&
                                        _feedPostIdBySource
                                            .containsKey(_feedPosts[index].id)
                                    ? () => _softRemoveFeedPost(
                                          _feedPosts[index],
                                        )
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
