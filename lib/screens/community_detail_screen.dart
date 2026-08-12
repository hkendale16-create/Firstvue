import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/community_news_service.dart';
import '../services/community_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/media_picker_sheet.dart';
import 'auth_screen.dart';
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
  List<CommunityMember> _members = const [];
  List<CommunityNewsPost> _posts = const [];
  bool _loading = true;
  bool _actionLoading = false;
  bool _posting = false;
  final _composer = TextEditingController();
  List<XFile> _attachedMedia = const [];

  @override
  void initState() {
    super.initState();
    if (widget.initialCommunity != null) {
      _community = widget.initialCommunity;
      _loading = false;
    }
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final community =
        await CommunityService.fetchCommunityById(widget.communityId);
    final members = community == null
        ? const <CommunityMember>[]
        : await CommunityService.fetchMembers(widget.communityId, limit: 24);
    final posts = await CommunityNewsService.fetchPostsForCommunity(
      widget.communityId,
      limit: 30,
    );
    if (!mounted) return;
    setState(() {
      _community = community ?? _community;
      _members = members;
      _posts = posts;
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
      if (community.isPending) {
        await CommunityService.cancelJoinRequest(community.id);
      } else if (community.isMember) {
        await CommunityService.leave(community.id);
      } else {
        final result = await CommunityService.join(community.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.requested
                    ? 'Join request sent.'
                    : 'You joined ${community.name}.',
              ),
            ),
          );
        }
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

  Future<void> _pickMedia() async {
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _attachedMedia = files);
  }

  Future<void> _createPost() async {
    final community = _community;
    if (community == null || !community.canPost) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      await _requireAuth();
      return;
    }

    final text = _composer.text.trim();
    if ((text.isEmpty && _attachedMedia.isEmpty) || _posting) return;

    setState(() => _posting = true);
    try {
      final post = await CommunityNewsService.createPost(
        text,
        communityId: community.id,
        files: _attachedMedia,
      );
      _composer.clear();
      if (!mounted) return;
      setState(() {
        _attachedMedia = const [];
        _posts = [post, ..._posts.where((p) => p.id != post.id)];
      });
    } on CommunityNewsMediaUploadException catch (error) {
      _composer.clear();
      if (!mounted) return;
      setState(() {
        _attachedMedia = const [];
        _posts = [error.post, ..._posts.where((p) => p.id != error.post.id)];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Post saved but media upload failed: ${error.cause}'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to post: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
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

  String get _joinLabel {
    final community = _community;
    if (community == null) return 'Join';
    if (community.isPending) return 'Cancel Request';
    if (community.isMember) return 'Leave';
    if (community.isPrivate) return 'Request to Join';
    return 'Join';
  }

  List<CommunityMember> get _leaders => _members
      .where((m) => m.role == 'owner' || m.role == 'admin' || m.role == 'moderator')
      .toList();

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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _CommunityHero(community: community),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _actionLoading ? null : _toggleJoin,
                              style: FilledButton.styleFrom(
                                backgroundColor: community.isMember ||
                                        community.isPending
                                    ? FirstVueColors.surface
                                    : FirstVueColors.coral,
                                foregroundColor: Colors.white,
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
                      if (community.canPost) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'CREATE POST',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _composer,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Post in ${community.name}…',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: .38),
                            ),
                            filled: true,
                            fillColor: FirstVueColors.elevatedSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _posting ? null : _pickMedia,
                              icon: const Icon(Icons.perm_media_outlined, size: 18),
                              label: Text(
                                _attachedMedia.isEmpty
                                    ? 'PHOTO / VIDEO'
                                    : '${_attachedMedia.length} ATTACHED',
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _posting ? null : _createPost,
                              style: FilledButton.styleFrom(
                                backgroundColor: FirstVueColors.coral,
                              ),
                              child: Text(
                                _posting ? 'POSTING…' : 'Post in Community',
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 28),
                      const Text(
                        'COMMUNITY FEED',
                        style: TextStyle(
                          color: FirstVueColors.gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loading && _posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: FirstVueColors.teal,
                            ),
                          ),
                        )
                      else if (_posts.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: FirstVueColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .08),
                            ),
                          ),
                          child: Text(
                            community.canPost
                                ? 'No posts yet. Create the first one.'
                                : 'No posts in this community yet.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .55),
                            ),
                          ),
                        )
                      else
                        ..._posts.map(
                          (post) => CommunityNewsPostCard(
                            key: ValueKey('community-feed-${post.id}'),
                            post: post,
                            style: CommunityNewsPostCardStyle.timeline,
                            onTap: () => CommunityNewsPostDetailSheet.show(
                              context,
                              postId: post.id,
                              initialPost: post,
                            ),
                            onAuthorTap: () => openMemberProfile(
                              context,
                              profileId: post.authorId,
                              displayName: post.authorName,
                            ),
                            onComment: () => FeedCommentsSheet.show(
                              context,
                              mediaId: post.commentsMediaId,
                              businessName: post.authorName,
                            ),
                          ),
                        ),
                      if (community.rules?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'RULES',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          community.rules!.trim(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (_leaders.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'LEADERS',
                          style: TextStyle(
                            color: FirstVueColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._leaders.map(
                          (member) => _MemberTile(
                            member: member,
                            showRole: true,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'MEMBERS · ${community.memberCount}',
                        style: const TextStyle(
                          color: FirstVueColors.gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_members.isEmpty)
                        const Text(
                          'No members yet.',
                          style: TextStyle(color: Colors.white54),
                        )
                      else
                        ..._members.map(
                          (member) => _MemberTile(member: member),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _CommunityHero extends StatelessWidget {
  final Community community;

  const _CommunityHero({required this.community});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FirstVueColors.elevatedSurface,
                  border: Border.all(
                    color: FirstVueColors.teal.withValues(alpha: .5),
                    width: 2,
                  ),
                  image: community.imageUrl != null &&
                          community.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(community.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: community.imageUrl == null ||
                        community.imageUrl!.isEmpty
                    ? Icon(
                        Icons.groups_rounded,
                        color: FirstVueColors.teal.withValues(alpha: .95),
                        size: 32,
                      )
                    : null,
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
                    if (community.category != null)
                      Text(
                        community.category!,
                        style: TextStyle(
                          color: FirstVueColors.teal.withValues(alpha: .85),
                          fontSize: 12,
                        ),
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
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                '${community.memberCount} members',
                style: const TextStyle(color: FirstVueColors.gold, fontSize: 13),
              ),
              Text(
                '${community.followerCount} followers',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 13,
                ),
              ),
              Text(
                community.isPrivate ? 'Private' : 'Public',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final CommunityMember member;
  final bool showRole;

  const _MemberTile({required this.member, this.showRole = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => openMemberProfile(
        context,
        profileId: member.userId,
        displayName: member.displayName,
      ),
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
      trailing: showRole ||
              member.role == 'admin' ||
              member.role == 'owner' ||
              member.role == 'moderator'
          ? Text(
              member.role[0].toUpperCase() + member.role.substring(1),
              style: const TextStyle(color: FirstVueColors.teal, fontSize: 12),
            )
          : null,
    );
  }
}
