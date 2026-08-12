import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'media_picker_sheet.dart';
import 'profile_recent_activity_section.dart';

enum EntityFeedScope { user, business, professional, event }

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
  final _composer = TextEditingController();
  List<XFile> _attachedMedia = const [];
  bool _posting = false;

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

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
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

  Future<void> _submitPost() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    final text = _composer.text.trim();
    if ((text.isEmpty && _attachedMedia.isEmpty) || _posting) return;

    setState(() => _posting = true);
    try {
      CommunityNewsPost newPost;
      try {
        newPost = await switch (widget.scope) {
          EntityFeedScope.business => CommunityNewsService.createPost(
              text,
              businessId: widget.entityId,
              files: _attachedMedia,
            ),
          EntityFeedScope.professional => CommunityNewsService.createPost(
              text,
              professionalProfileId: widget.entityId,
              files: _attachedMedia,
            ),
          EntityFeedScope.event => CommunityNewsService.createPost(
              text,
              eventId: widget.entityId,
              files: _attachedMedia,
            ),
          EntityFeedScope.user => CommunityNewsService.createPost(
              text,
              files: _attachedMedia,
            ),
        };
      } on CommunityNewsMediaUploadException catch (error) {
        newPost = error.post;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post saved but media failed: ${error.cause}')),
          );
        }
      }

      _composer.clear();
      if (!mounted) return;
      setState(() {
        _attachedMedia = const [];
        _posts = [
          newPost,
          for (final post in _posts)
            if (post.id != newPost.id) post,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? 'Sign in to post.'
                : 'Unable to post right now.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _pickMedia() async {
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _attachedMedia = [..._attachedMedia, ...files]);
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

  ProfileActivityScope get _activityScope {
    return switch (widget.scope) {
      EntityFeedScope.business => ProfileActivityScope.business,
      EntityFeedScope.professional => ProfileActivityScope.professional,
      EntityFeedScope.event => ProfileActivityScope.event,
      EntityFeedScope.user => ProfileActivityScope.user,
    };
  }

  Widget _buildComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10151B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'POST AN UPDATE',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _composer,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share news, links, photos, or videos…',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: .38)),
              filled: true,
              fillColor: FirstVueColors.elevatedSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_attachedMedia.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${_attachedMedia.length} file${_attachedMedia.length == 1 ? '' : 's'} attached',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: _posting ? null : _pickMedia,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                color: FirstVueColors.teal,
                tooltip: 'Add photo or video',
              ),
              const Spacer(),
              FilledButton(
                onPressed: _posting ? null : _submitPost,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: Colors.black,
                ),
                child: Text(_posting ? 'Posting…' : 'Post'),
              ),
            ],
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
              style: TextStyle(color: Colors.white.withValues(alpha: .45)),
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
                const Expanded(
                  child: Text(
                    'NEWS FEED',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refreshPosts,
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.white38),
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
                color: const Color(0xFF10151B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
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
                  color: selected ? FirstVueColors.gold : Colors.white54,
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
