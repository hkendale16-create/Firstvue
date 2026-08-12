import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/firstvue_feed_service.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../models/post_identity.dart';
import '../services/community_news_service.dart';
import '../services/post_identity_service.dart';
import '../services/post_identity_store.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_feed.dart';
import 'local_media_thumbnail.dart';
import 'post_identity_selector.dart';
import 'media_picker_sheet.dart';

/// Home News Feed — thin composer shell over the shared [FirstVueFeed] engine.
///
/// Label is always NEWS FEED (never Community Feed). Community/Group feeds
/// use a separate [FirstVueFeedScope.community]/[FirstVueFeedScope.group].
class HomeNewsFeedSection extends StatefulWidget {
  final int refreshToken;

  const HomeNewsFeedSection({super.key, this.refreshToken = 0});

  @override
  State<HomeNewsFeedSection> createState() => _HomeNewsFeedSectionState();
}

class _HomeNewsFeedSectionState extends State<HomeNewsFeedSection> {
  final GlobalKey<FirstVueFeedState> _feedKey = GlobalKey<FirstVueFeedState>();
  final _composer = TextEditingController();
  bool _posting = false;
  List<XFile> _attachedMedia = const [];
  List<PostIdentityOption> _identityOptions = const [];
  PostIdentityOption? _selectedIdentity;
  int _localRefresh = 0;

  @override
  void initState() {
    super.initState();
    _loadIdentityOptions();
  }

  @override
  void didUpdateWidget(covariant HomeNewsFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() => _localRefresh++);
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadIdentityOptions() async {
    final options = await PostIdentityService.fetchOptions();
    if (!mounted) return;
    final storedKey = await PostIdentityStore.loadSelectedKey();
    final restored = PostIdentityOption.matchStoredKey(options, storedKey);
    setState(() {
      _identityOptions = options;
      _selectedIdentity = restored ?? (options.isEmpty ? null : options.first);
    });
  }

  Future<void> refresh() async {
    await _feedKey.currentState?.refresh();
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
      setState(() => _attachedMedia = const []);
      _feedKey.currentState?.prependPost(newPost);
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
      CommunityNewsService.logFeedError(error, context: 'HomeNewsFeed.post');
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

  Widget _buildComposer() {
    return Column(
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
                side: BorderSide(
                  color: FirstVueColors.teal.withValues(alpha: .45),
                ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return FirstVueFeed(
      key: _feedKey,
      scope: FirstVueFeedScope.home,
      refreshToken: widget.refreshToken + _localRefresh,
      title: 'NEWS FEED',
      emptyMessage: 'No posts yet',
      enableRealtime: true,
      enablePagination: true,
      header: _buildComposer(),
    );
  }
}
