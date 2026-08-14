import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/share_payload.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/followers_following_screen.dart';
import '../screens/full_screen_media_viewer.dart';
import '../services/web_seo_service.dart';
import '../services/community_news_service.dart';
import '../services/follow_service.dart';
import '../services/profile_media_service.dart';
import '../services/user_profile_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/social_chrome.dart';
import '../messaging/screens/messaging_shell_screen.dart';
import '../messaging/services/fv_messaging_service.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/profile_affiliations_section.dart';
import '../widgets/signed_media_viewer.dart';
import '../auth/ensure_signed_in.dart';

void openMemberProfile(
  BuildContext context, {
  required String profileId,
  String? displayName,
}) {
  if (profileId.trim().isEmpty) return;
  Navigator.push(
    context,
    FirstVuePageRoute(
      builder: (_) => MemberPublicProfileScreen(
        profileId: profileId,
        displayNameHint: displayName,
      ),
    ),
  );
}

class MemberPublicProfileScreen extends StatefulWidget {
  final String profileId;
  final String? displayNameHint;

  const MemberPublicProfileScreen({
    super.key,
    required this.profileId,
    this.displayNameHint,
  });

  @override
  State<MemberPublicProfileScreen> createState() =>
      _MemberPublicProfileScreenState();
}

class _MemberPublicProfileScreenState extends State<MemberPublicProfileScreen> {
  static const _tabLabels = ['POSTS', 'PHOTOS', 'GROUPS', 'COMMUNITIES'];

  ProfileImageSet _profileImages = const ProfileImageSet();
  ProfileEngagementStats _stats = const ProfileEngagementStats(
    postCount: 0,
    sparksReceived: 0,
  );
  List<CommunityNewsPost> _posts = const [];
  List<ProfileMediaItem> _gallery = const [];

  String? _displayName;
  String? _username;
  bool _loading = true;
  int _selectedTab = 0;
  FollowStatus _followStatus = FollowStatus.notFollowing;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _followBusy = false;

  bool get _isSelf =>
      Supabase.instance.client.auth.currentUser?.id == widget.profileId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      UserProfileService.fetchProfileForUser(widget.profileId),
      ProfileMediaService.fetchProfileImagesForUser(widget.profileId),
      CommunityNewsService.fetchEngagementStatsForAuthor(widget.profileId),
      CommunityNewsService.fetchPostsByAuthor(widget.profileId),
      ProfileMediaService.fetchGalleryMediaForUser(widget.profileId),
      FollowService.followStatus(widget.profileId),
      FollowService.fetchFollowerCount(widget.profileId),
      FollowService.fetchFollowingCount(widget.profileId),
    ]);
    if (!mounted) return;
    final profile = results[0] as UserProfile?;
    setState(() {
      _displayName = profile?.displayName;
      _username = profile?.username;
      _profileImages = results[1] as ProfileImageSet;
      _stats = results[2] as ProfileEngagementStats;
      _posts = results[3] as List<CommunityNewsPost>;
      _gallery = results[4] as List<ProfileMediaItem>;
      _followStatus = results[5] as FollowStatus;
      _followerCount = results[6] as int;
      _followingCount = results[7] as int;
      _loading = false;
    });
    WebSeoService.update(
      title: '$_title · FirstVue',
      description: _subtitle ?? 'FirstVue member profile',
      canonicalUrl: AppConfig.memberShareUrl(widget.profileId),
    );
  }

  Future<void> _toggleFollow() async {
    if (_isSelf || _followBusy) return;
    setState(() => _followBusy = true);
    try {
      if (_followStatus == FollowStatus.following) {
        await FollowService.unfollow(widget.profileId);
        if (!mounted) return;
        setState(() {
          _followStatus = FollowStatus.notFollowing;
          _followerCount = (_followerCount - 1).clamp(0, 999999);
        });
      } else if (_followStatus == FollowStatus.pending) {
        await FollowService.unfollow(widget.profileId);
        if (!mounted) return;
        setState(() => _followStatus = FollowStatus.notFollowing);
      } else {
        await FollowService.follow(widget.profileId);
        if (!mounted) return;
        final next = await FollowService.followStatus(widget.profileId);
        setState(() {
          _followStatus = next;
          if (next == FollowStatus.following) {
            _followerCount += 1;
          }
        });
      }
    } on AuthException {
      if (!mounted) return;
      await ensureSignedIn(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update follow right now.')),
      );
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  String _followLabel() {
    return switch (_followStatus) {
      FollowStatus.following => 'Following',
      FollowStatus.pending => 'Requested',
      FollowStatus.notFollowing => 'Follow',
    };
  }

  Future<void> _openMessage() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await ensureSignedIn(context);
      return;
    }
    try {
      final threadId = await FvMessagingService.openDirect(
        otherUserId: widget.profileId,
      );
      if (!mounted) return;
      await openMessaging(context, conversationId: threadId, title: _title);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start a message right now.')),
      );
    }
  }

  String get _title {
    final hint = widget.displayNameHint?.trim();
    if (hint != null && hint.isNotEmpty) return hint;
    final name = _displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'FirstVue member';
  }

  String? get _subtitle {
    final handle = _username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'FirstVue member';
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
            updated.savedByMe ? 'Saved to Favorites' : 'Removed from Favorites',
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
      await ensureSignedIn(context);
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
      await ensureSignedIn(context);
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

  void _viewAvatar() {
    final avatar = _profileImages.avatar;
    if (avatar == null) return;
    openSignedMedia(
      context,
      url: avatar.signedUrl,
      isVideo: avatar.isVideo,
      title: 'PROFILE PHOTO',
    );
  }

  void _viewCover() {
    final cover = _profileImages.cover;
    if (cover == null) return;
    openSignedMedia(
      context,
      url: cover.signedUrl,
      isVideo: cover.isVideo,
      title: 'COVER PHOTO',
    );
  }

  Widget _buildPostsTab() {
    final fv = context.fv;
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
        child: Text(
          'No community posts yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: fv.secondaryText),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
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
              onSpark: () => _sparkPost(index),
              onSave: () => _savePost(index),
              onShare: () => FirstVueShareSheet.show(
                context,
                payload: SharePayload(
                  title: _posts[index].authorName,
                  link: AppConfig.newsPostShareUrl(_posts[index].id),
                  subtitle: _posts[index].body,
                ),
              ),
              onComment: () => FeedCommentsSheet.show(
                context,
                mediaId: _posts[index].commentsMediaId,
                businessName: _posts[index].authorName,
              ),
            ),
          if (_posts.length >= 20)
            TextButton(
              onPressed: () async {
                final more = await CommunityNewsService.fetchPostsByAuthor(
                  widget.profileId,
                  limit: 20,
                  beforeCreatedAt: _posts.last.createdAt,
                  beforeId: _posts.last.id,
                );
                if (!mounted || more.isEmpty) return;
                final existing = _posts.map((p) => p.id).toSet();
                setState(() {
                  _posts = [
                    ..._posts,
                    ...more.where((p) => existing.add(p.id)),
                  ];
                });
              },
              child: const Text('Load more posts'),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotosTab() {
    if (_gallery.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
        child: Text(
          'No photos or videos yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .45)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _gallery.length,
        itemBuilder: (context, index) {
          final media = _gallery[index];
          final hasCaption = media.caption?.trim().isNotEmpty == true;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () async {
                if (media.isVideo) {
                  openSignedMedia(
                    context,
                    url: media.signedUrl,
                    isVideo: true,
                    title: 'VIDEO',
                  );
                  return;
                }
                final images = _gallery
                    .where((e) => !e.isVideo)
                    .map(
                      (e) => FullScreenMediaItem(
                        url: e.signedUrl,
                        isVideo: false,
                        caption: e.caption,
                      ),
                    )
                    .toList();
                final imageIndex =
                    images.indexWhere((e) => e.url == media.signedUrl);
                await openFullScreenImageViewer(
                  context,
                  items: images,
                  initialIndex: imageIndex < 0 ? 0 : imageIndex,
                  title: 'PHOTO',
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SignedMediaThumbnail(
                    url: media.signedUrl,
                    isVideo: media.isVideo,
                    fit: BoxFit.cover,
                  ),
                  if (hasCaption)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                          child: Text(
                            media.caption!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(_title, style: const TextStyle(fontSize: 16)),
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            SocialProfileHeader(
              name: _title,
              handle: _subtitle,
              coverImageUrl: _profileImages.cover?.signedUrl,
              avatarImageUrl: _profileImages.avatar?.signedUrl,
              coverIsVideo: _profileImages.cover?.isVideo ?? false,
              avatarIsVideo: _profileImages.avatar?.isVideo ?? false,
              centerAvatar: true,
              onCoverTap: _profileImages.cover != null ? _viewCover : null,
              onAvatarTap: _profileImages.avatar != null ? _viewAvatar : null,
              stats: [
                ProfileStatItem(
                  label: 'posts',
                  value: _loading ? '—' : '${_stats.postCount}',
                ),
                ProfileStatItem(
                  label: 'followers',
                  value: _loading ? '—' : '$_followerCount',
                  onTap: _loading
                      ? null
                      : () => Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => FollowersFollowingScreen(
                              profileId: widget.profileId,
                              displayName: _title,
                              mode: FollowListMode.followers,
                            ),
                          ),
                        ),
                ),
                ProfileStatItem(
                  label: 'following',
                  value: _loading ? '—' : '$_followingCount',
                  onTap: _loading
                      ? null
                      : () => Navigator.push(
                          context,
                          FirstVuePageRoute(
                            builder: (_) => FollowersFollowingScreen(
                              profileId: widget.profileId,
                              displayName: _title,
                              mode: FollowListMode.following,
                            ),
                          ),
                        ),
                ),
              ],
              actions: _isSelf
                  ? const []
                  : [
                      SocialFollowButton(
                        label: _followLabel(),
                        filled: _followStatus != FollowStatus.following,
                        onPressed: _loading || _followBusy
                            ? null
                            : _toggleFollow,
                      ),
                      SocialFollowButton(
                        label: 'Message',
                        filled: false,
                        onPressed: _openMessage,
                      ),
                    ],
            ),
            const SizedBox(height: 8),
            SocialGoldUnderlineTabs(
              labels: _tabLabels,
              selectedIndex: _selectedTab,
              onSelected: (index) => setState(() => _selectedTab = index),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: FirstVueColors.teal),
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_selectedTab),
                  child: switch (_selectedTab) {
                    0 => _buildPostsTab(),
                    1 => _buildPhotosTab(),
                    2 => ProfileAffiliationsSection(
                      profileId: widget.profileId,
                      showGroups: true,
                      showCommunities: false,
                    ),
                    _ => ProfileAffiliationsSection(
                      profileId: widget.profileId,
                      showGroups: false,
                      showCommunities: true,
                    ),
                  },
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
