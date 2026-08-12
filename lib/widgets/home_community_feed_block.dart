import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../services/community_news_service.dart';
import '../services/interaction_preferences_service.dart';
import '../services/profile_media_service.dart';
import '../services/repost_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'local_media_thumbnail.dart';
import 'media_picker_sheet.dart';
import 'profile_avatar_thumbnail.dart';

/// Facebook-style composer + news feed for the Home Communities container.
class HomeCommunityFeedBlock extends StatefulWidget {
  const HomeCommunityFeedBlock({
    super.key,
    this.refreshToken = 0,
    this.maxPosts = 12,
  });

  final int refreshToken;
  final int maxPosts;

  @override
  State<HomeCommunityFeedBlock> createState() => _HomeCommunityFeedBlockState();
}

class _HomeCommunityFeedBlockState extends State<HomeCommunityFeedBlock> {
  final _composer = TextEditingController();

  List<CommunityNewsPost> _posts = const [];
  Set<String> _repostedPostIds = const {};
  List<XFile> _attachedMedia = const [];
  bool _loading = true;
  bool _posting = false;
  String? _error;
  String? _avatarUrl;
  String _displayName = 'you';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant HomeCommunityFeedBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadFeed();
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadProfileHint(), _loadFeed()]);
  }

  Future<void> _loadProfileHint() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final rowFuture = Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final imagesFuture = ProfileMediaService.fetchProfileImagesForUser(user.id);
      final row = await rowFuture;
      final images = await imagesFuture;
      if (!mounted) return;
      final name = (row?['display_name'] as String?)?.trim();
      final avatar = images.avatar?.signedUrl;
      setState(() {
        if (name != null && name.isNotEmpty) _displayName = name;
        if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
      });
    } catch (_) {
      // Non-blocking.
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await CommunityNewsService.fetchCommunityFeedPosts(
        limit: widget.maxPosts,
      );
      final postIds = posts.map((p) => p.id).toList();
      final reposted = await RepostService.fetchMyRepostedIds(postIds);
      final repostCounts = await RepostService.fetchRepostCounts(postIds);
      if (!mounted) return;
      setState(() {
        _posts = posts
            .map((p) => p.copyWith(repostCount: repostCounts[p.id] ?? 0))
            .toList(growable: false);
        _repostedPostIds = reposted;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      CommunityNewsService.logFeedError(
        error,
        context: 'HomeCommunityFeedBlock.load',
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load community posts.';
      });
    }
  }

  Future<void> _ensureSignedIn() async {
    if (Supabase.instance.client.auth.currentUser != null) return;
    await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _publish() async {
    await _ensureSignedIn();
    if (Supabase.instance.client.auth.currentUser == null) return;

    final text = _composer.text.trim();
    if ((text.isEmpty && _attachedMedia.isEmpty) || _posting) return;

    setState(() => _posting = true);
    try {
      CommunityNewsPost created;
      try {
        created = await CommunityNewsService.createPost(
          text,
          files: _attachedMedia,
        );
      } on CommunityNewsMediaUploadException catch (error) {
        created = error.post;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Post saved but media upload failed: ${error.cause}',
              ),
            ),
          );
        }
      }
      if (!mounted) return;
      _composer.clear();
      setState(() {
        _attachedMedia = const [];
        _posts = [
          created,
          for (final post in _posts)
            if (post.id != created.id) post,
        ].take(widget.maxPosts).toList(growable: false);
        _posting = false;
      });
      FocusScope.of(context).unfocus();
    } catch (error) {
      CommunityNewsService.logFeedError(
        error,
        context: 'HomeCommunityFeedBlock.publish',
      );
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? 'Sign in to post.'
                : 'Unable to post right now.',
          ),
        ),
      );
    }
  }

  Future<void> _showMediaPicker() async {
    await _ensureSignedIn();
    if (Supabase.instance.client.auth.currentUser == null || !mounted) return;
    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _attachedMedia = [..._attachedMedia, ...files]);
  }

  Future<void> _sparkPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final previous = post;
    final willSpark = !post.sparkedByMe;
    final optimistic = post.copyWith(
      sparkedByMe: willSpark,
      sparkCount: post.sparkCount + (willSpark ? 1 : -1),
    );
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index) optimistic else _posts[i],
      ];
    });
    if (willSpark) {
      await InteractionPreferencesService.playSparkFeedback(fromUserTap: true);
    }
    try {
      final updated = await CommunityNewsService.toggleSpark(post);
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) updated else _posts[i],
        ];
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      await _ensureSignedIn();
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
    final previous = post;
    final optimistic = post.copyWith(savedByMe: !post.savedByMe);
    setState(() {
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index) optimistic else _posts[i],
      ];
    });
    try {
      final updated = await CommunityNewsService.toggleSave(post);
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) updated else _posts[i],
        ];
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      await _ensureSignedIn();
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

  Future<void> _repostPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasReposted = _repostedPostIds.contains(post.id);
    setState(() {
      _repostedPostIds = wasReposted
          ? _repostedPostIds.where((id) => id != post.id).toSet()
          : {..._repostedPostIds, post.id};
    });
    try {
      await RepostService.toggleRepost(
        post.id,
        currentlyReposted: wasReposted,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasReposted ? 'Repost removed' : 'Reposted'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _repostedPostIds = wasReposted
            ? {..._repostedPostIds, post.id}
            : _repostedPostIds.where((id) => id != post.id).toSet();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to repost right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPost =
        (_composer.text.trim().isNotEmpty || _attachedMedia.isNotEmpty) &&
            !_posting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Facebook-style composer
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: FirstVueColors.elevatedSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: FirstVueColors.ivory.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatarThumbnail(
                    imageUrl: _avatarUrl,
                    displayName: _displayName,
                    radius: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: FirstVueColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: FirstVueColors.ivory.withValues(alpha: 0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(
                          color: FirstVueColors.ivory,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        decoration: InputDecoration(
                          hintText: "What's on your mind, $_displayName?",
                          hintStyle: TextStyle(
                            color: FirstVueColors.ivory.withValues(alpha: 0.38),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ],
              ),
              if (_attachedMedia.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachedMedia.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final file = _attachedMedia[index];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          LocalMediaThumbnail(
                            file: file,
                            size: 72,
                            onTap: () => LocalMediaThumbnail.previewLocalFile(
                              context,
                              file,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                backgroundColor: FirstVueColors.surface,
                                foregroundColor: Colors.white70,
                                minimumSize: const Size(24, 24),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                setState(() {
                                  _attachedMedia = [
                                    for (var i = 0;
                                        i < _attachedMedia.length;
                                        i++)
                                      if (i != index) _attachedMedia[i],
                                  ];
                                });
                              },
                              icon: const Icon(Icons.close, size: 14),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: FirstVueColors.ivory.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ComposerAction(
                    icon: Icons.photo_library_outlined,
                    label: 'Photo',
                    color: FirstVueColors.teal,
                    onTap: _posting ? null : _showMediaPicker,
                  ),
                  _ComposerAction(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: FirstVueColors.coral,
                    onTap: _posting ? null : _showMediaPicker,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: canPost ? _publish : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: FirstVueColors.coral,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          FirstVueColors.coral.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _posting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Post',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: FirstVueColors.teal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'NEWS FEED',
              style: TextStyle(
                color: FirstVueColors.ivory,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _loadFeed,
              icon: const Icon(
                Icons.refresh,
                color: FirstVueColors.mutedIcon,
                size: 20,
              ),
              tooltip: 'Refresh feed',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading && _posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_error != null && _posts.isEmpty)
          _EmptyFeedState(
            title: _error!,
            actionLabel: 'Try again',
            onAction: _loadFeed,
          )
        else if (_posts.isEmpty)
          const _EmptyFeedState(
            title: 'No community posts yet',
            subtitle: 'Be the first to share something with your community.',
          )
        else
          Column(
            children: [
              for (var index = 0; index < _posts.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                CommunityNewsPostCard(
                  post: _posts[index],
                  style: CommunityNewsPostCardStyle.timeline,
                  onTap: () => CommunityNewsPostDetailSheet.show(
                    context,
                    postId: _posts[index].id,
                    initialPost: _posts[index],
                  ),
                  onAuthorTap: _posts[index].authorId.isNotEmpty
                      ? () => openMemberProfile(
                            context,
                            profileId: _posts[index].authorId,
                            displayName: _posts[index].authorName,
                          )
                      : null,
                  onSpark: () => _sparkPost(index),
                  onSave: () => _savePost(index),
                  onComment: () => FeedCommentsSheet.show(
                    context,
                    mediaId: _posts[index].commentsMediaId,
                    businessName: _posts[index].authorName,
                  ),
                  onRepost: () => _repostPost(index),
                  repostedByMe: _repostedPostIds.contains(_posts[index].id),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: FirstVueColors.ivory.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      decoration: BoxDecoration(
        color: FirstVueColors.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FirstVueColors.ivory.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.newspaper_outlined,
            size: 28,
            color: FirstVueColors.mutedIcon,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FirstVueColors.ivory,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FirstVueColors.ivory.withValues(alpha: 0.54),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
