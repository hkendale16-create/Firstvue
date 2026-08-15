import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/entity_profile_feed_section.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/group_circle_avatar.dart';
import '../widgets/network_photo.dart';
import '../auth/ensure_signed_in.dart';
import 'edit_community_screen.dart';
import 'member_public_profile_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;
  final Community? initialCommunity;

  const CommunityDetailScreen({
    super.key,
    required this.communityId,
    this.initialCommunity,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  Community? _community;
  CommunityMember? _leader;
  List<CommunityMember> _members = const [];
  List<CommunityMember> _pending = const [];
  bool _loading = true;
  bool _actionLoading = false;
  int _feedRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialCommunity != null) {
      _community = widget.initialCommunity;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final community =
        await CommunityService.fetchCommunityById(widget.communityId);
    final leader = await CommunityService.fetchGroupLeader(widget.communityId);
    final members = community == null
        ? const <CommunityMember>[]
        : await CommunityService.fetchMembers(widget.communityId, limit: 20);
    final me = Supabase.instance.client.auth.currentUser?.id;
    final canManage = community != null &&
        me != null &&
        community.canManageAs(me);
    final pending = canManage
        ? await CommunityService.fetchMembers(
            widget.communityId,
            limit: 20,
            status: 'pending',
          )
        : const <CommunityMember>[];
    if (!mounted) return;
    setState(() {
      _community = community ?? _community;
      _leader = leader;
      _members = members;
      _pending = pending;
      _loading = false;
      _feedRefreshToken++;
    });
  }

  Future<void> _requireAuth() async {
    await ensureSignedIn(context);
  }

  Future<void> _toggleJoin() async {
    final community = _community;
    if (community == null) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      await _requireAuth();
      return;
    }

    setState(() => _actionLoading = true);
    try {
      if (community.isMember) {
        await CommunityService.leave(community.id);
      } else if (community.isPendingMember) {
        await CommunityService.cancelJoinRequest(community.id);
      } else {
        await CommunityService.join(community.id);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update membership.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final community = _community;
    if (community == null) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      await _requireAuth();
      return;
    }

    setState(() => _actionLoading = true);
    try {
      if (community.isFollowing) {
        await CommunityService.unfollow(community.id);
      } else {
        await CommunityService.follow(community.id);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update follow status.')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _edit() async {
    final community = _community;
    if (community == null) return;
    final navigator = Navigator.of(context);
    final updated = await navigator.push<Object?>(
      FirstVuePageRoute(
        builder: (_) => EditCommunityScreen(community: community),
      ),
    );
    if (!mounted) return;
    if (updated == 'deleted') {
      navigator.pop();
      return;
    }
    if (updated is Community) {
      setState(() => _community = updated);
      await _load();
    }
  }

  void _share() {
    final community = _community;
    if (community == null) return;
    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: community.name,
        subtitle: community.description ?? 'Join us on FirstVue',
        link: '${AppConfig.webBaseUrl}/?community=${community.id}',
      ),
    );
  }

  void _openProfile(CommunityMember member) {
    openMemberProfile(
      context,
      profileId: member.userId,
      displayName: member.displayName,
    );
  }

  String get _joinLabel {
    final community = _community;
    if (community == null) return 'Join';
    if (community.isMember) return 'Leave group';
    if (community.isPendingMember) return 'Cancel request';
    if (community.isPrivate) return 'Request to Join';
    return 'Join group';
  }

  @override
  Widget build(BuildContext context) {
    final community = _community;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final canManage = community != null && me != null && community.canManageAs(me);
    final canPost = community != null && community.canPostAs(me);
    final fv = context.fv;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: null,
        title: Text(community?.name ?? 'Group'),
        actions: [
          if (canManage)
            IconButton(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit group',
            ),
          IconButton(
            onPressed: community == null ? null : _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: _loading && community == null
          ? const Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            )
          : community == null
              ? Center(
                  child: Text(
                    'Group not found.',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                )
              : FirstVueRefreshScaffold(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            GroupCircleAvatar(
                              imageUrl: community.imageUrl,
                              size: 84,
                              ringColor: FirstVueColors.teal,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    community.name,
                                    style: TextStyle(color: fv.primaryText,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (community.locationLabel != null)
                                    Text(
                                      community.locationLabel!,
                                      style: TextStyle(color: fv.secondaryText,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      _chip(
                                        community.isPublic
                                            ? 'Public'
                                            : 'Private',
                                      ),
                                      if (community.category?.isNotEmpty ==
                                          true)
                                        _chip(community.category!),
                                      Text(
                                        '${community.memberCount} members · '
                                        '${community.followerCount} followers',
                                        style: const TextStyle(
                                          color: FirstVueColors.gold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (community.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            community.description!.trim(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (_leader != null) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: InkWell(
                            onTap: () => _openProfile(_leader!),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              children: [
                                NetworkCircleAvatar(
                                  imageUrl: _leader!.avatarUrl,
                                  radius: 18,
                                  backgroundColor:
                                      FirstVueColors.elevatedSurface,
                                  placeholder: Text(
                                    _leader!.displayName.isNotEmpty
                                        ? _leader!.displayName[0]
                                            .toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: FirstVueColors.gold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _leader!.displayName,
                                        style: TextStyle(color: fv.primaryText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        [
                                          if (_leader!.username != null)
                                            '@${_leader!.username}',
                                          'Group Leader',
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: FirstVueColors.teal,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF8A8696),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _actionLoading ? null : _toggleJoin,
                                style: FilledButton.styleFrom(
                                  backgroundColor: community.isMember
                                      ? FirstVueColors.surface
                                      : FirstVueColors.coral,
                                  foregroundColor: null,
                                ),
                                child: Text(
                                  _actionLoading ? '…' : _joinLabel,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _actionLoading ? null : _toggleFollow,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: null,
                                  side: BorderSide(
                                    color: community.isFollowing
                                        ? FirstVueColors.teal
                                        : Colors.white.withValues(alpha: .25),
                                  ),
                                ),
                                child: Text(
                                  community.isFollowing
                                      ? 'Following'
                                      : 'Follow',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (community.rules?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'RULES',
                            style: TextStyle(
                              color: FirstVueColors.gold,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            community.rules!.trim(),
                            style: TextStyle(color: fv.secondaryText,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (_pending.isNotEmpty && canManage) ...[
                        const SizedBox(height: 24),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'JOIN REQUESTS',
                            style: TextStyle(
                              color: FirstVueColors.gold,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ..._pending.map(
                          (member) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            leading: CircleAvatar(
                              backgroundColor: FirstVueColors.elevatedSurface,
                              child: Text(
                                member.displayName.isNotEmpty
                                    ? member.displayName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(
                              member.displayName,
                              style: TextStyle(color: fv.primaryText),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await CommunityService.reviewMembership(
                                      communityId: community.id,
                                      profileId: member.userId,
                                      approve: true,
                                    );
                                    await _load();
                                  },
                                  child: const Text('Approve'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await CommunityService.reviewMembership(
                                      communityId: community.id,
                                      profileId: member.userId,
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
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'GROUP NEWS FEED',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      EntityProfileFeedSection(
                        scope: EntityFeedScope.community,
                        entityId: community.id,
                        canPost: canPost,
                        refreshToken: _feedRefreshToken,
                        showHeader: false,
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'MEMBERS',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _members.isEmpty
                            ? Text('No members yet.', style: TextStyle(color: fv.secondaryText),
                              )
                            : Column(
                                children: [
                                  ..._members.map(
                                    (member) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      onTap: () => _openProfile(member),
                                      leading: NetworkCircleAvatar(
                                        backgroundColor:
                                            FirstVueColors.elevatedSurface,
                                        imageUrl: member.avatarUrl,
                                        placeholder: Text(
                                          member.displayName.isNotEmpty
                                              ? member.displayName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: FirstVueColors.gold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        member.displayName,
                                        style: TextStyle(color: fv.primaryText,
                                        ),
                                      ),
                                      subtitle: member.username != null
                                          ? Text(
                                              '@${member.username}',
                                              style: TextStyle(color: fv.secondaryText,
                                              ),
                                            )
                                          : null,
                                      trailing: Text(
                                        member.roleLabel,
                                        style: TextStyle(
                                          color: member.isGroupLeader
                                              ? FirstVueColors.teal
                                              : Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _chip(String label) {
    final fv = context.fv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fv.elevatedSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fv.secondaryText, fontSize: 11),
      ),
    );
  }
}
