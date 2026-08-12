import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/followers_following_screen.dart';
import '../services/web_seo_service.dart';
import '../services/community_news_service.dart';
import '../services/follow_service.dart';
import '../services/profile_media_service.dart';
import '../services/user_profile_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/community_news_post_card.dart';
import '../widgets/community_news_post_detail_sheet.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/feed_comments_sheet.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../widgets/profile_photo_actions.dart';
import '../widgets/signed_media_viewer.dart';
import 'auth_screen.dart';

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
  static const _tabLabels = ['POSTS', 'PHOTOS'];

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
  bool _imageUpdating = false;

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
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
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

  Future<void> _handlePhotoTap({required bool isAvatar}) async {
    if (!_isSelf) {
      if (isAvatar) {
        _viewAvatar();
      } else {
        _viewCover();
      }
      return;
    }
    if (_imageUpdating) return;

    final existing = isAvatar ? _profileImages.avatar : _profileImages.cover;
    final action = await showProfilePhotoActionSheet(
      context,
      changeLabel: isAvatar ? 'Change profile photo' : 'Change cover photo',
      viewLabel: isAvatar ? 'View profile photo' : 'View cover photo',
      removeLabel: isAvatar ? 'Remove profile photo' : 'Remove cover photo',
      hasExisting: existing != null,
    );
    if (!mounted || action == null) return;

    if (action == ProfilePhotoAction.view) {
      if (existing == null) return;
      await viewProfilePhoto(
        context,
        url: existing.signedUrl,
        isVideo: existing.isVideo,
        title: isAvatar ? 'PROFILE PHOTO' : 'COVER PHOTO',
      );
      return;
    }

    if (action == ProfilePhotoAction.remove) {
      setState(() => _imageUpdating = true);
      try {
        if (isAvatar) {
          await ProfileMediaService.removeAvatar();
        } else {
          await ProfileMediaService.removeCover();
        }
        await _loadAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAvatar ? 'Profile photo removed.' : 'Cover photo removed.',
            ),
          ),
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

    final picked = await pickProfilePhoto(context, allowVideo: isAvatar);
    if (picked == null || !mounted) return;

    setState(() => _imageUpdating = true);
    try {
      if (isAvatar) {
        await ProfileMediaService.setAvatar(picked);
      } else {
        await ProfileMediaService.setCover(picked);
      }
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAvatar ? 'Profile photo updated.' : 'Cover photo updated.',
          ),
        ),
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

  Widget _buildPostsTab() {
    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
        child: Text(
          'No community posts yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: .45)),
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
              onComment: () => FeedCommentsSheet.show(
                context,
                mediaId: _posts[index].commentsMediaId,
                businessName: _posts[index].authorName,
              ),
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
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => openSignedMedia(
                context,
                url: media.signedUrl,
                isVideo: media.isVideo,
                title: media.isVideo ? 'VIDEO' : 'PHOTO',
              ),
              child: SignedMediaThumbnail(
                url: media.signedUrl,
                isVideo: media.isVideo,
                fit: BoxFit.cover,
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
      backgroundColor: const Color(0xFF080B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0F),
        foregroundColor: Colors.white,
        title: Text(_title, style: const TextStyle(fontSize: 16)),
      ),
      body: FirstVueRefreshScaffold(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            FacebookStyleProfileHeader(
              title: _title,
              subtitle: _subtitle ?? 'FirstVue member',
              coverImageUrl: _profileImages.cover?.signedUrl,
              avatarImageUrl: _profileImages.avatar?.signedUrl,
              coverIsVideo: _profileImages.cover?.isVideo ?? false,
              avatarIsVideo: _profileImages.avatar?.isVideo ?? false,
              onCoverTap: _imageUpdating
                  ? null
                  : (_isSelf || _profileImages.cover != null)
                      ? () => _handlePhotoTap(isAvatar: false)
                      : null,
              onAvatarTap: _imageUpdating
                  ? null
                  : (_isSelf || _profileImages.avatar != null)
                      ? () => _handlePhotoTap(isAvatar: true)
                      : null,
              showImageLoading: _loading || _imageUpdating,
              stats: [
                ProfileStatItem(
                  label: 'Posts',
                  value: _loading ? '—' : '${_stats.postCount}',
                ),
                ProfileStatItem(
                  label: 'Followers',
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
                  label: 'Following',
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
                ProfileStatItem(
                  label: 'Sparks',
                  value: _loading ? '—' : '${_stats.sparksReceived}',
                ),
              ],
            ),
            if (!_isSelf) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading || _followBusy ? null : _toggleFollow,
                    style: FilledButton.styleFrom(
                      backgroundColor: _followStatus == FollowStatus.following
                          ? const Color(0xFF151B22)
                          : FirstVueColors.gold,
                      foregroundColor: _followStatus == FollowStatus.following
                          ? Colors.white
                          : Colors.black,
                    ),
                    child: _followBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_followLabel()),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        child: _MemberProfileTabButton(
                          label: _tabLabels[i],
                          selected: _selectedTab == i,
                          onTap: () => setState(() => _selectedTab = i),
                        ),
                      ),
                  ],
                ),
              ),
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
                  child: _selectedTab == 0 ? _buildPostsTab() : _buildPhotosTab(),
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _MemberProfileTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MemberProfileTabButton({
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
