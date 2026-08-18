import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../auth/ensure_signed_in.dart';
import '../models/publish_destination.dart';
import '../screens/boost_post_sheet.dart';
import '../screens/create_post_screen.dart';
import '../screens/edit_post_screen.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'profile_recent_activity_section.dart';

enum EntityFeedScope { user, business, professional, event, community }

/// Posts + activity tabs for member, business, professional, and event profiles.
class EntityProfileFeedSection extends StatefulWidget {
  final EntityFeedScope scope;
  final String? entityId;
  final String? authorId;
  final bool canPost;
  final int refreshToken;
  final bool showHeader;

  const EntityProfileFeedSection({
    super.key,
    required this.scope,
    this.entityId,
    this.authorId,
    this.canPost = false,
    this.refreshToken = 0,
    this.showHeader = true,
  });

  @override
  State<EntityProfileFeedSection> createState() =>
      _EntityProfileFeedSectionState();
}

class _EntityProfileFeedSectionState extends State<EntityProfileFeedSection> {
  static const _tabLabels = ['POSTS', 'ACTIVITY'];

  int _selectedTab = 0;
  late Future<List<CommunityNewsPost>> _postsFuture;
  List<CommunityNewsPost> _posts = const [];

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  @override
  void didUpdateWidget(covariant EntityProfileFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.entityId != widget.entityId ||
        oldWidget.authorId != widget.authorId ||
        oldWidget.scope != widget.scope) {
      _postsFuture = _loadPosts();
    }
  }

  Future<List<CommunityNewsPost>> _loadPosts() async {
    final posts = switch (widget.scope) {
      EntityFeedScope.business => widget.entityId == null
          ? const <CommunityNewsPost>[]
          : await CommunityNewsService.fetchPostsForBusiness(widget.entityId!),
      EntityFeedScope.professional => widget.entityId == null
          ? const <CommunityNewsPost>[]
          : await CommunityNewsService.fetchPostsForProfessional(
              widget.entityId!,
            ),
      EntityFeedScope.event => widget.entityId == null
          ? const <CommunityNewsPost>[]
          : await CommunityNewsService.fetchPostsForEvent(widget.entityId!),
      EntityFeedScope.community => widget.entityId == null
          ? const <CommunityNewsPost>[]
          : await CommunityNewsService.fetchPostsForCommunity(widget.entityId!),
      EntityFeedScope.user => widget.authorId != null
          ? await CommunityNewsService.fetchPostsByAuthor(widget.authorId!)
          : await CommunityNewsService.fetchMyPosts(),
    };
    if (mounted) setState(() => _posts = posts);
    return posts;
  }

  Future<void> _refreshPosts() async {
    setState(() => _postsFuture = _loadPosts());
    await _postsFuture;
  }

  Future<void> _openCreatePost() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }

    final result = await Navigator.push<CommunityNewsPost>(
      context,
      FirstVuePageRoute(
        builder: (_) => CreatePostScreen(
          businessId: widget.scope == EntityFeedScope.business
              ? widget.entityId
              : null,
          professionalProfileId: widget.scope == EntityFeedScope.professional
              ? widget.entityId
              : null,
          communityId: widget.scope == EntityFeedScope.community
              ? widget.entityId
              : null,
          eventId:
              widget.scope == EntityFeedScope.event ? widget.entityId : null,
          lockIdentity: widget.scope != EntityFeedScope.user,
          initialDestination: widget.scope == EntityFeedScope.user
              ? PublishDestination.feed
              : PublishDestination.entityOnly,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _posts = [
        result,
        for (final post in _posts)
          if (post.id != result.id) post,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post published.')),
    );
  }

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final previous = post;
    final optimistic = post.copyWith(
      sparkedByMe: !post.sparkedByMe,
      sparkCount: post.sparkCount + (post.sparkedByMe ? -1 : 1),
    );
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index) optimistic else _posts[i],
      ];
    });
    try {
      final updated = await CommunityNewsService.toggleSpark(post);
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) updated else _posts[i],
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
    }
  }

  Future<void> _savePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    try {
      final updated = await CommunityNewsService.toggleSave(post);
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) updated else _posts[i],
        ];
      });
    } catch (_) {}
  }

  Future<void> _deletePost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final deleted = await confirmDeleteNewsPost(context, _posts[index]);
    if (!deleted || !mounted) return;
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i != index) _posts[i],
      ];
    });
  }

  Future<void> _editPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final updated = await EditPostScreen.open(context, post: _posts[index]);
    if (updated == null || !mounted) return;
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index) updated else _posts[i],
      ];
    });
  }

  ProfileActivityScope get _activityScope {
    return switch (widget.scope) {
      EntityFeedScope.business => ProfileActivityScope.business,
      EntityFeedScope.professional => ProfileActivityScope.professional,
      EntityFeedScope.event => ProfileActivityScope.event,
      EntityFeedScope.user || EntityFeedScope.community =>
        ProfileActivityScope.user,
    };
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CREATE',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openCreatePost,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: context.fv.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Share news, links, photos, or videos…',
                  style: TextStyle(color: context.fv.tertiaryText),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _openCreatePost,
              style: FilledButton.styleFrom(
                backgroundColor: FirstVueColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Create post'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab() {
    return FutureBuilder<List<CommunityNewsPost>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            ),
          );
        }

        final posts = snapshot.data ?? _posts;
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            child: Text(
              widget.canPost
                  ? 'No posts yet. Share your first update above.'
                  : 'No posts yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.fv.secondaryText),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (var index = 0; index < posts.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CommunityNewsPostCard(
                    post: posts[index],
                    style: CommunityNewsPostCardStyle.timeline,
                    onTap: () => CommunityNewsPostDetailSheet.show(
                      context,
                      postId: posts[index].id,
                      initialPost: posts[index],
                    ),
                    onSpark: () => _sparkPost(index),
                    onSave: () => _savePost(index),
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: posts[index].commentsMediaId,
                      businessName: posts[index].authorName,
                    ),
                    onDelete: posts[index].isMine ? () => _deletePost(index) : null,
                    onEdit: posts[index].isMine ? () => _editPost(index) : null,
                    onBoost: posts[index].isMine ||
                            (widget.canPost &&
                                widget.scope == EntityFeedScope.business)
                        ? () => openBoostPostFlow(context, posts[index])
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    switch (widget.scope) {
                      EntityFeedScope.community => 'GROUP NEWS FEED',
                      EntityFeedScope.business => 'BUSINESS FEED',
                      EntityFeedScope.professional => 'PROFESSIONAL FEED',
                      EntityFeedScope.event => 'EVENT FEED',
                      EntityFeedScope.user => 'PROFILE FEED',
                    },
                    style: TextStyle(
                      color: context.fv.secondaryText,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refreshPosts,
                  icon: Icon(Icons.refresh, size: 18, color: context.fv.mutedIcon),
                  tooltip: 'Refresh feed',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).extension<FirstVuePalette>()?.surface ?? FirstVueColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _tabLabels.length; i++)
                    Expanded(
                      child: _FeedTabButton(
                        label: _tabLabels[i],
                        selected: _selectedTab == i,
                        onTap: () => setState(() => _selectedTab = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.canPost && _selectedTab == 0) _buildComposer(),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_selectedTab),
            child: _selectedTab == 0
                ? _buildPostsTab()
                : ProfileRecentActivitySection(
                    scope: _activityScope,
                    businessId: widget.scope == EntityFeedScope.business
                        ? widget.entityId
                        : null,
                    professionalProfileId:
                        widget.scope == EntityFeedScope.professional
                            ? widget.entityId
                            : null,
                    eventId: widget.scope == EntityFeedScope.event
                        ? widget.entityId
                        : null,
                    refreshToken: widget.refreshToken,
                    embedded: true,
                  ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FeedTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? FirstVueColors.gold : context.fv.secondaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 2,
                width: 32,
                decoration: BoxDecoration(
                  color: selected ? FirstVueColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
