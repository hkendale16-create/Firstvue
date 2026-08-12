import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../screens/member_public_profile_screen.dart';
import '../models/post_identity.dart';
import '../services/community_news_service.dart';
import '../services/post_identity_service.dart';
import '../services/post_identity_store.dart';
import '../services/interaction_preferences_service.dart';
import '../services/repost_service.dart';
import '../theme/firstvue_theme.dart';
import '../utils/app_environment.dart';
import 'community_news_post_card.dart';
import 'community_news_post_detail_sheet.dart';
import 'feed_comments_sheet.dart';
import 'local_media_thumbnail.dart';
import 'post_identity_selector.dart';
import 'media_picker_sheet.dart';

class HomeNewsFeedSection extends StatefulWidget {
  final int refreshToken;

  const HomeNewsFeedSection({super.key, this.refreshToken = 0});

  @override
  State<HomeNewsFeedSection> createState() => _HomeNewsFeedSectionState();
}

class _HomeNewsFeedSectionState extends State<HomeNewsFeedSection> {
  List<CommunityNewsPost> _posts = const [];
  Set<String> _repostedPostIds = const {};
  bool _loadingPosts = true;
  String? _loadError;
  final _composer = TextEditingController();
  bool _posting = false;
  List<XFile> _attachedMedia = const [];
  RealtimeChannel? _newsChannel;
  List<PostIdentityOption> _identityOptions = const [];
  PostIdentityOption? _selectedIdentity;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadIdentityOptions();
    _subscribeToNewsFeed();
  }

  Future<void> _loadIdentityOptions() async {
    final options = await PostIdentityService.fetchOptions();
    if (!mounted) return;
    final storedKey = await PostIdentityStore.loadSelectedKey();
    final restored = PostIdentityOption.matchStoredKey(options, storedKey);
    setState(() {
      _identityOptions = options;
      _selectedIdentity =
          restored ?? (options.isEmpty ? null : options.first);
    });
  }

  @override
  void didUpdateWidget(covariant HomeNewsFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _newsChannel?.unsubscribe();
    _composer.dispose();
    super.dispose();
  }

  void _subscribeToNewsFeed() {
    if (isWidgetTestBinding) return;
    _newsChannel?.unsubscribe();
    _newsChannel = Supabase.instance.client
        .channel('home-news-feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'community_news_posts',
          callback: (payload) async {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            if (record['status'] != 'approved') return;

            final postId = record['id'] as String?;
            if (postId == null) return;
            if (_posts.any((post) => post.id == postId)) return;

            final post = await CommunityNewsService.fetchPostById(postId);
            if (post == null || !mounted) return;

            setState(() {
              _posts = [
                post,
                for (final existing in _posts)
                  if (existing.id != post.id) existing,
              ];
            });
          },
        )
        .subscribe();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingPosts = true;
      _loadError = null;
    });
    try {
      final posts = await CommunityNewsService.fetchPosts();
      final postIds = posts.map((p) => p.id).toList();
      final reposted = await RepostService.fetchMyRepostedIds(postIds);
      final repostCounts = await RepostService.fetchRepostCounts(postIds);
      if (!mounted) return;
      setState(() {
        _posts = posts
            .map(
              (p) => p.copyWith(repostCount: repostCounts[p.id] ?? 0),
            )
            .toList();
        _repostedPostIds = reposted;
        _loadingPosts = false;
        _loadError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingPosts = false;
          _loadError = error.toString();
        });
      }
    }
  }

  Future<void> refresh() => _loadPosts();

  Future<void> _refresh() => _loadPosts();

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
      final hadMedia = _attachedMedia.isNotEmpty;
      CommunityNewsPost newPost;
      try {
        final identity = _selectedIdentity;
        newPost = await CommunityNewsService.createPost(
          text,
          businessId: identity?.businessId,
          communityId: identity?.communityId,
          files: _attachedMedia,
        );
      } on CommunityNewsMediaUploadException catch (error) {
        newPost = error.post;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Post saved but photo/video upload failed: ${error.cause}',
              ),
            ),
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
        _loadingPosts = false;
      });
      if (hadMedia && newPost.media.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Post saved without media. Check Supabase migrations or storage buckets.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
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
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _showMediaPicker() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      return;
    }

    final files = await showMediaPickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _attachedMedia = [..._attachedMedia, ...files]);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.savedByMe
                ? 'Saved to Favorites'
                : 'Removed from Favorites',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save this post right now.')),
      );
    }
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
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previous else _posts[i],
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to spark this post right now.')),
      );
    }
  }

  Future<void> _repostPost(int index) async {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    final wasReposted = _repostedPostIds.contains(post.id);

    if (!wasReposted) {
      final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF10151B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.repeat, color: FirstVueColors.teal),
                title: const Text('Repost', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'repost'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note, color: FirstVueColors.gold),
                title: const Text(
                  'Repost with comment',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(ctx, 'comment'),
              ),
            ],
          ),
        ),
      );
      if (action == null || !mounted) return;

      String? comment;
      if (action == 'comment') {
        comment = await _promptRepostComment();
        if (comment == null) return;
      }

      await _applyRepost(index, post, wasReposted: false, comment: comment);
      return;
    }

    await _applyRepost(index, post, wasReposted: true);
  }

  Future<String?> _promptRepostComment() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10151B),
        title: const Text('Add a comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Say something about this post…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Repost'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _applyRepost(
    int index,
    CommunityNewsPost post, {
    required bool wasReposted,
    String? comment,
  }) async {
    setState(() {
      if (wasReposted) {
        _repostedPostIds =
            _repostedPostIds.where((id) => id != post.id).toSet();
      } else {
        _repostedPostIds = {..._repostedPostIds, post.id};
      }
    });

    try {
      await RepostService.toggleRepost(
        post.id,
        currentlyReposted: wasReposted,
        comment: comment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasReposted ? 'Repost removed' : 'Reposted to your feed'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _repostedPostIds = wasReposted
            ? {..._repostedPostIds, post.id}
            : _repostedPostIds.where((id) => id != post.id).toSet();
      });
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
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

  Future<void> _showPostMenu(int index) async {
    await _deletePost(index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'COMMUNITY FEED',
                style: TextStyle(
                  color: FirstVueColors.ivory,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            if (!_loadingPosts)
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, color: FirstVueColors.mutedIcon, size: 20),
                tooltip: 'Refresh feed',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FirstVueColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FirstVueColors.gold.withValues(alpha: .35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'POST HERE',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (_identityOptions.isNotEmpty && _selectedIdentity != null)
                PostIdentitySelector(
                  options: _identityOptions,
                  selected: _selectedIdentity!,
                  onChanged: (value) {
                    setState(() => _selectedIdentity = value);
                    PostIdentityStore.saveSelected(value);
                  },
                ),
              TextField(
                controller: _composer,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Share news… Use #hashtags and @usernames in your post.',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: .38)),
                  filled: true,
                  fillColor: FirstVueColors.elevatedSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_attachedMedia.isNotEmpty) ...[
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
                                    for (var i = 0; i < _attachedMedia.length; i++)
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
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _showMediaPicker,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FirstVueColors.teal,
                      side: BorderSide(color: FirstVueColors.teal.withValues(alpha: .45)),
                    ),
                    icon: const Icon(Icons.perm_media_outlined, size: 18),
                    label: Text(
                      _attachedMedia.isEmpty
                          ? 'PHOTO / VIDEO'
                          : '${_attachedMedia.length} ATTACHED',
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _posting ? null : _submitPost,
                    style: FilledButton.styleFrom(
                      backgroundColor: FirstVueColors.coral,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_posting ? 'POSTING...' : 'POST'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_loadingPosts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: FirstVueColors.teal),
            ),
          )
        else if (_loadError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to load posts. Pull to refresh or tap below.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .54)),
                ),
                TextButton(onPressed: _refresh, child: const Text('Try again')),
              ],
            ),
          )
        else if (_posts.isEmpty)
          const Text(
            'Community posts will appear here.',
            style: TextStyle(color: Colors.white54),
          )
        else
          Column(
            children: [
              for (var index = 0; index < _posts.length; index++)
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
                  onDelete: _posts[index].isMine
                      ? () => _showPostMenu(index)
                      : null,
                  onComment: () => FeedCommentsSheet.show(
                    context,
                    mediaId: _posts[index].commentsMediaId,
                    businessName: _posts[index].authorName,
                  ),
                  onRepost: () => _repostPost(index),
                  repostedByMe: _repostedPostIds.contains(_posts[index].id),
                ),
            ],
          ),
      ],
    );
  }
}
