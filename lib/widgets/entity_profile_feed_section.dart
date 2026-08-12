import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../feed/firstvue_feed_service.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/auth_screen.dart';
import '../services/community_news_service.dart';
import '../theme/firstvue_theme.dart';
import 'firstvue_feed.dart';
import 'media_picker_sheet.dart';
import 'profile_recent_activity_section.dart';

enum EntityFeedScope { user, business, professional, event, community, group }

/// Posts + activity tabs for member, business, professional, event, and group profiles.
///
/// Uses the shared [FirstVueFeed] engine (no outer bordered feed shell).
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

  final GlobalKey<FirstVueFeedState> _feedKey = GlobalKey<FirstVueFeedState>();
  int _selectedTab = 0;
  final _composer = TextEditingController();
  List<XFile> _attachedMedia = const [];
  bool _posting = false;
  int _feedRefresh = 0;

  FirstVueFeedScope get _feedScope => switch (widget.scope) {
        EntityFeedScope.user => FirstVueFeedScope.personal,
        EntityFeedScope.business => FirstVueFeedScope.business,
        EntityFeedScope.professional => FirstVueFeedScope.professional,
        EntityFeedScope.event => FirstVueFeedScope.event,
        EntityFeedScope.community => FirstVueFeedScope.community,
        EntityFeedScope.group => FirstVueFeedScope.group,
      };

  @override
  void didUpdateWidget(covariant EntityProfileFeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.entityId != widget.entityId ||
        oldWidget.authorId != widget.authorId ||
        oldWidget.scope != widget.scope) {
      setState(() => _feedRefresh++);
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  ProfileActivityScope get _activityScope {
    return switch (widget.scope) {
      EntityFeedScope.business => ProfileActivityScope.business,
      EntityFeedScope.professional => ProfileActivityScope.professional,
      EntityFeedScope.event => ProfileActivityScope.event,
      EntityFeedScope.community ||
      EntityFeedScope.group ||
      EntityFeedScope.user =>
        ProfileActivityScope.user,
    };
  }

  Future<void> _pickMedia() async {
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
          EntityFeedScope.community || EntityFeedScope.group =>
            CommunityNewsService.createPost(
              text,
              communityId: widget.entityId,
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
      setState(() => _attachedMedia = const []);
      _feedKey.currentState?.prependPost(newPost);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published.')),
      );
    } catch (error) {
      CommunityNewsService.logFeedError(error, context: 'EntityFeed.post');
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

  Widget _buildComposer() {
    // Borderless composer — no heavy outer card.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                for (var i = 0; i < _tabLabels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _selectedTab = i),
                    style: TextButton.styleFrom(
                      foregroundColor: _selectedTab == i
                          ? FirstVueColors.gold
                          : Colors.white54,
                    ),
                    child: Text(_tabLabels[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_selectedTab == 0) ...[
          if (widget.canPost) _buildComposer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FirstVueFeed(
              key: _feedKey,
              scope: _feedScope,
              entityId: widget.entityId,
              authorId: widget.authorId,
              refreshToken: widget.refreshToken + _feedRefresh,
              showTitle: false,
              emptyMessage: widget.canPost
                  ? 'No posts yet. Share your first update above.'
                  : 'No posts yet',
              enablePagination: true,
            ),
          ),
        ] else
          ProfileRecentActivitySection(
            scope: _activityScope,
            businessId: widget.scope == EntityFeedScope.business
                ? widget.entityId
                : null,
            professionalProfileId: widget.scope == EntityFeedScope.professional
                ? widget.entityId
                : null,
            eventId:
                widget.scope == EntityFeedScope.event ? widget.entityId : null,
            refreshToken: widget.refreshToken,
          ),
      ],
    );
  }
}
