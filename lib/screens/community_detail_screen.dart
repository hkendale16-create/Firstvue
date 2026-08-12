import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/entity_profile_feed_section.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import 'auth_screen.dart';
import '../navigation/firstvue_page_route.dart';

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
  List<CommunityMember> _members = const [];
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
    final members = community == null
        ? const <CommunityMember>[]
        : await CommunityService.fetchMembers(widget.communityId, limit: 12);
    if (!mounted) return;
    setState(() {
      _community = community ?? _community;
      _members = members;
      _loading = false;
      _feedRefreshToken++;
    });
  }

  Future<void> _requireAuth() async {
    await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const AuthScreen()),
    );
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

  @override
  Widget build(BuildContext context) {
    final community = _community;
    final me = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: Text(community?.name ?? 'Community'),
        actions: [
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
              ? const Center(
                  child: Text(
                    'Group not found.',
                    style: TextStyle(color: Colors.white54),
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
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: FirstVueColors.elevatedSurface,
                              backgroundImage:
                                  community.imageUrl != null &&
                                          community.imageUrl!.isNotEmpty
                                      ? NetworkImage(community.imageUrl!)
                                      : null,
                              child: community.imageUrl == null ||
                                      community.imageUrl!.isEmpty
                                  ? const Icon(
                                      Icons.groups_rounded,
                                      color: FirstVueColors.teal,
                                      size: 32,
                                    )
                                  : null,
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
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (community.locationLabel != null)
                                    Text(
                                      community.locationLabel!,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
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
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _actionLoading
                                      ? '…'
                                      : community.isMember
                                          ? 'Leave group'
                                          : 'Join group',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _actionLoading ? null : _toggleFollow,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
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
                      const SizedBox(height: 28),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'GROUP FEED',
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
                        canPost: community.isMember ||
                            community.creatorId == me,
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
                            ? const Text(
                                'No members yet.',
                                style: TextStyle(color: Colors.white54),
                              )
                            : Column(
                                children: [
                                  ..._members.map(
                                    (member) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            FirstVueColors.elevatedSurface,
                                        child: Text(
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: member.username != null
                                          ? Text(
                                              '@${member.username}',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                              ),
                                            )
                                          : null,
                                      trailing: member.role == 'admin'
                                          ? const Text(
                                              'Admin',
                                              style: TextStyle(
                                                color: FirstVueColors.teal,
                                                fontSize: 12,
                                              ),
                                            )
                                          : null,
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
}
