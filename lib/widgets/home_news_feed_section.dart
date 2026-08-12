import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import 'community_news_post_card.dart';
import 'feed_comments_sheet.dart';
import 'media_picker_sheet.dart';

class HomeNewsFeedSection extends StatefulWidget {
  const HomeNewsFeedSection({super.key});

  @override
  State<HomeNewsFeedSection> createState() => _HomeNewsFeedSectionState();
}

class _HomeNewsFeedSectionState extends State<HomeNewsFeedSection> {
  List<CommunityNewsPost> _posts = const [];
  bool _loadingPosts = true;
  String? _loadError;
  final _composer = TextEditingController();
  bool _posting = false;
  List<XFile> _attachedMedia = const [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingPosts = true;
      _loadError = null;
    });
    try {
      final posts = await CommunityNewsService.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
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
        newPost = await CommunityNewsService.createPost(
          text,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEWS FEED',
          style: TextStyle(
            color: FirstVueColors.ivory,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
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
              TextField(
                controller: _composer,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share news, updates, or shoutouts with the community...',
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
                      final isVideo = _isVideoFile(file);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 72,
                              height: 72,
                              color: FirstVueColors.elevatedSurface,
                              child: isVideo
                                  ? const Icon(Icons.videocam_outlined, color: FirstVueColors.teal)
                                  : const Icon(Icons.image_outlined, color: FirstVueColors.gold),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CommunityNewsPostCard(
                    post: _posts[index],
                    onSpark: () => _sparkPost(index),
                    onSave: () => _savePost(index),
                    onComment: () => FeedCommentsSheet.show(
                      context,
                      mediaId: _posts[index].commentsMediaId,
                      businessName: _posts[index].authorName,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  bool _isVideoFile(XFile file) {
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;
    const videoExtensions = {'mp4', 'mov', 'webm', 'avi', 'mkv', '3gp', 'm4v'};
    final extension = file.name.split('.').last.toLowerCase();
    return videoExtensions.contains(extension);
  }
}
