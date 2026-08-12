import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/profile_photo_actions.dart';
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
  bool _imageUpdating = false;

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

  bool get _isCreator {
    final community = _community;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (community == null || userId == null) return false;
    return community.creatorId == userId;
  }

  Future<void> _handleGroupPhotoTap() async {
    final community = _community;
    if (community == null || _imageUpdating) return;

    final hasPhoto = (community.imageUrl ?? '').trim().isNotEmpty;
    if (!_isCreator) {
      if (!hasPhoto) return;
      await viewProfilePhoto(
        context,
        url: community.imageUrl!,
        isVideo: false,
        title: 'GROUP PHOTO',
      );
      return;
    }

    final action = await showProfilePhotoActionSheet(
      context,
      changeLabel: 'Change group photo',
      viewLabel: 'View group photo',
      removeLabel: 'Remove group photo',
      hasExisting: hasPhoto,
    );
    if (!mounted || action == null) return;

    if (action == ProfilePhotoAction.view) {
      if (!hasPhoto) return;
      await viewProfilePhoto(
        context,
        url: community.imageUrl!,
        isVideo: false,
        title: 'GROUP PHOTO',
      );
      return;
    }

    if (action == ProfilePhotoAction.remove) {
      setState(() => _imageUpdating = true);
      try {
        final updated =
            await CommunityService.removeCommunityImage(community.id);
        if (!mounted) return;
        setState(() => _community = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group photo removed.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove photo: $e')),
        );
      } finally {
        if (mounted) setState(() => _imageUpdating = false);
      }
      return;
    }

    final picked = await pickProfilePhoto(context, allowVideo: false);
    if (picked == null || !mounted) return;

    setState(() => _imageUpdating = true);
    try {
      final updated = await CommunityService.updateCommunityImage(
        communityId: community.id,
        file: picked,
      );
      if (!mounted) return;
      setState(() => _community = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group photo updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _imageUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final community = _community;

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
          ? const Center(child: CircularProgressIndicator(color: FirstVueColors.teal))
          : community == null
              ? const Center(child: Text('Group not found.', style: TextStyle(color: Colors.white54)))
              : FirstVueRefreshScaffold(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FirstVueColors.teal.withValues(alpha: .25),
                              FirstVueColors.surface,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: .08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: (_isCreator ||
                                          (community.imageUrl ?? '')
                                              .trim()
                                              .isNotEmpty)
                                      ? _handleGroupPhotoTap
                                      : null,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor:
                                            FirstVueColors.elevatedSurface,
                                        backgroundImage: (community.imageUrl ??
                                                    '')
                                                .trim()
                                                .isNotEmpty
                                            ? NetworkImage(community.imageUrl!)
                                            : null,
                                        child: (community.imageUrl ?? '')
                                                .trim()
                                                .isEmpty
                                            ? Icon(
                                                Icons.groups_rounded,
                                                color: FirstVueColors.teal
                                                    .withValues(alpha: .95),
                                                size: 28,
                                              )
                                            : null,
                                      ),
                                      if (_imageUpdating)
                                        const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: FirstVueColors.gold,
                                          ),
                                        )
                                      else if (_isCreator)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10151B),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.photo_camera_outlined,
                                              size: 12,
                                              color: FirstVueColors.gold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                          style: const TextStyle(color: Colors.white54),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (community.description?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 14),
                              Text(
                                community.description!.trim(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .78),
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              '${community.memberCount} member${community.memberCount == 1 ? '' : 's'}',
                              style: const TextStyle(color: FirstVueColors.gold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
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
                              onPressed: _actionLoading ? null : _toggleFollow,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: community.isFollowing
                                      ? FirstVueColors.teal
                                      : Colors.white.withValues(alpha: .25),
                                ),
                              ),
                              child: Text(community.isFollowing ? 'Following' : 'Follow'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'GROUP FEED',
                        style: TextStyle(
                          color: FirstVueColors.gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: FirstVueColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: .08)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.dynamic_feed_outlined,
                              color: Colors.white.withValues(alpha: .35),
                              size: 36,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Group posts coming soon',
                              style: TextStyle(color: Colors.white.withValues(alpha: .55)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'MEMBERS',
                        style: TextStyle(
                          color: FirstVueColors.gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_members.isEmpty)
                        const Text('No members yet.', style: TextStyle(color: Colors.white54))
                      else
                        ..._members.map(
                          (member) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: FirstVueColors.elevatedSurface,
                              child: Text(
                                member.displayName.isNotEmpty
                                    ? member.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: FirstVueColors.gold),
                              ),
                            ),
                            title: Text(
                              member.displayName,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: member.username != null
                                ? Text(
                                    '@${member.username}',
                                    style: const TextStyle(color: Colors.white54),
                                  )
                                : null,
                            trailing: member.role == 'admin'
                                ? const Text('Admin', style: TextStyle(color: FirstVueColors.teal, fontSize: 12))
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
