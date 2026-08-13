import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_following_screen.dart';
import 'my_business_profile_view_screen.dart';
import 'my_businesses_screen.dart';
import 'my_professional_profile_view_screen.dart';
import '../services/business_submission_service.dart';
import '../services/community_news_service.dart';
import '../services/profile_media_service.dart';
import '../services/follow_service.dart';
import '../services/professional_profiles_service.dart';
import '../services/user_profile_service.dart';
import '../services/profile_privacy_service.dart';
import '../services/username_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/signed_media_viewer.dart' show openSignedMedia;
import '../widgets/portfolio_albums_section.dart';
import '../widgets/profile_affiliations_section.dart';
import '../widgets/profile_completion_banner.dart';
import '../widgets/profile_media_section.dart';
import '../widgets/profile_my_posts_section.dart';
import '../widgets/profile_saved_section.dart';
import '../widgets/firstvue_refresh_scaffold.dart';
import '../config/app_config.dart';
import '../services/portfolio_album_service.dart';
import '../widgets/firstvue_share_sheet.dart';
import '../widgets/follow_requests_section.dart';
import '../widgets/live_stream_eligibility_card.dart';
import '../widgets/firstvue_settings_drawer.dart';
import '../widgets/firstvue_inline_search_bar.dart';
import '../models/share_payload.dart';

class ProfileScreen extends StatefulWidget {
  final int refreshToken;

  const ProfileScreen({super.key, this.refreshToken = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileImageSet _profileImages = const ProfileImageSet();
  bool _imagesLoading = false;
  bool _imageUpdating = false;
  ProfileEngagementStats _stats = const ProfileEngagementStats(
    postCount: 0,
    sparksReceived: 0,
  );
  bool _statsLoading = false;
  String? _displayName;
  String? _username;
  bool _nameLoading = false;
  bool _showEmailOnProfile = false;
  int _followerCount = 0;
  int _followingCount = 0;
  int _selectedTab = 0;
  int _pullRefreshToken = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<OwnedBusiness> _approvedBusinesses = const [];
  bool _hasApprovedProfessional = false;

  static const _tabLabels = [
    'POSTS',
    'PHOTOS',
    'PORTFOLIO',
    'GROUPS',
    'COMMUNITIES',
    'ABOUT',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileImages();
    _loadStats();
    _loadDisplayName();
    _loadPrivacy();
    _loadManagedProfiles();
  }

  Future<void> _loadManagedProfiles() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _approvedBusinesses = const [];
          _hasApprovedProfessional = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        BusinessSubmissionService.fetchMyBusinesses(),
        ProfessionalProfilesService.fetchMine(),
      ]);
      if (!mounted) return;
      final businesses = (results[0] as List<OwnedBusiness>)
          .where((b) => b.status == 'approved')
          .toList();
      final professional = results[1] as ProfessionalProfile?;
      setState(() {
        _approvedBusinesses = businesses;
        _hasApprovedProfessional = professional?.status == 'approved';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _approvedBusinesses = const [];
        _hasApprovedProfessional = false;
      });
    }
  }

  Future<void> _loadPrivacy() async {
    final show = await ProfilePrivacyService.showEmailOnProfile();
    if (mounted) setState(() => _showEmailOnProfile = show);
  }

  Future<void> _loadDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _displayName = null;
          _username = null;
        });
      }
      return;
    }
    setState(() => _nameLoading = true);
    final profile = await UserProfileService.fetchProfile();
    final username = await UsernameService.fetchUsername();
    if (!mounted) return;
    setState(() {
      _displayName = profile?.displayName?.trim().isNotEmpty == true
          ? profile!.displayName!.trim()
          : user.email?.split('@').first;
      _username = username ?? profile?.username;
      _nameLoading = false;
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadProfileImages();
      _loadStats();
      _loadDisplayName();
      _loadPrivacy();
      _loadManagedProfiles();
    }
  }

  Future<void> _loadStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _stats = const ProfileEngagementStats(postCount: 0, sparksReceived: 0);
        });
      }
      return;
    }
    setState(() => _statsLoading = true);
    final results = await Future.wait([
      CommunityNewsService.fetchMyEngagementStats(),
      FollowService.fetchFollowerCount(user.id),
      FollowService.fetchFollowingCount(user.id),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as ProfileEngagementStats;
      _followerCount = results[1] as int;
      _followingCount = results[2] as int;
      _statsLoading = false;
    });
  }

  void _openFollowList(FollowListMode mode, String displayName) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    Navigator.push(
      context,
      FirstVuePageRoute(
        builder: (_) => FollowersFollowingScreen(
          profileId: user.id,
          displayName: displayName,
          mode: mode,
        ),
      ),
    );
  }

  Future<void> _loadProfileImages() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _profileImages = const ProfileImageSet());
      return;
    }
    setState(() => _imagesLoading = true);
    final images = await ProfileMediaService.fetchProfileImages();
    if (!mounted) return;
    setState(() {
      _profileImages = images;
      _imagesLoading = false;
    });
  }

  Future<void> _showAvatarOptions() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await _handleAccountTap(null);
      return;
    }
    final hasAvatar = _profileImages.avatar != null;
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
              leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFFD8B56A)),
              title: const Text('Change profile photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            if (hasAvatar) ...[
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Color(0xFF78B9BE)),
                title: const Text('View profile photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white54),
                title: const Text('Remove profile photo', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeProfileImage(isAvatar: true);
    } else if (action == 'view') {
      final avatar = _profileImages.avatar;
      if (avatar != null && mounted) {
        openSignedMedia(
          context,
          url: avatar.signedUrl,
          isVideo: avatar.isVideo,
          title: 'PROFILE PHOTO',
        );
      }
    } else if (action == 'change') {
      await _changeProfileImage(isAvatar: true);
    }
  }

  Future<void> _showCoverOptions() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await _handleAccountTap(null);
      return;
    }
    final hasCover = _profileImages.cover != null;
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
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFD8B56A)),
              title: const Text('Change cover photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'change'),
            ),
            if (hasCover) ...[
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Color(0xFF78B9BE)),
                title: const Text('View cover photo', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, 'view'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white54),
                title: const Text('Remove cover photo', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeProfileImage(isAvatar: false);
    } else if (action == 'view') {
      final cover = _profileImages.cover;
      if (cover != null && mounted) {
        openSignedMedia(
          context,
          url: cover.signedUrl,
          isVideo: cover.isVideo,
          title: 'COVER PHOTO',
        );
      }
    } else if (action == 'change') {
      await _changeProfileImage(isAvatar: false);
    }
  }

  Future<void> _changeProfileImage({required bool isAvatar}) async {
    final files = await showImagePickerSheet(context);
    if (files == null || files.isEmpty || !mounted) return;
    setState(() => _imageUpdating = true);
    try {
      if (isAvatar) {
        await ProfileMediaService.setAvatar(files.first);
      } else {
        await ProfileMediaService.setCover(files.first);
      }
      await _loadProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAvatar ? 'Profile photo updated.' : 'Cover photo updated.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAvatar
                  ? 'Unable to update profile photo.'
                  : 'Unable to update cover photo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _imageUpdating = false);
    }
  }

  Future<void> _removeProfileImage({required bool isAvatar}) async {
    setState(() => _imageUpdating = true);
    try {
      if (isAvatar) {
        await ProfileMediaService.removeAvatar();
      } else {
        await ProfileMediaService.removeCover();
      }
      await _loadProfileImages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAvatar ? 'Profile photo removed.' : 'Cover photo removed.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to remove photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _imageUpdating = false);
    }
  }

  Future<void> _handleAccountTap(User? user) async {
    if (user == null) {
      final needsHandle = await Navigator.push<bool>(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
      if (mounted) {
        setState(() {});
        await _loadStats();
        await _loadDisplayName();
        await _loadManagedProfiles();
        if (needsHandle == true) {
          await _openEditProfile();
        }
      }
    } else {
      await Supabase.instance.client.auth.signOut();
    }

    if (mounted) {
      setState(() {});
      await _loadStats();
    }
  }

  int get _effectiveRefreshToken => widget.refreshToken + _pullRefreshToken;

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadProfileImages(),
      _loadStats(),
      _loadDisplayName(),
      _loadPrivacy(),
      _loadManagedProfiles(),
    ]);
    if (mounted) setState(() => _pullRefreshToken++);
  }

  Future<void> _shareProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await _handleAccountTap(null);
      return;
    }

    final name = _displayName?.trim().isNotEmpty == true
        ? _displayName!.trim()
        : (user.email?.split('@').first ?? 'My FirstVue profile');

    FirstVueShareSheet.show(
      context,
      payload: SharePayload(
        title: name,
        subtitle: 'See my posts, photos & ratings on FirstVue',
        link: AppConfig.memberShareUrl(user.id),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await _handleAccountTap(null);
      return;
    }
    final updated = await Navigator.push<EditProfileSaveResult>(
      context,
      FirstVuePageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        if (updated.username.isNotEmpty) {
          _username = updated.username;
        }
        if (updated.displayName.isNotEmpty) {
          _displayName = updated.displayName;
        }
      });
      await Future.wait([
        _loadDisplayName(),
        _loadProfileImages(),
      ]);
      setState(() => _pullRefreshToken++);
    }
  }

  Future<void> _openMyBusiness() async {
    if (_approvedBusinesses.isEmpty) return;
    if (_approvedBusinesses.length == 1) {
      await Navigator.push(
        context,
        FirstVuePageRoute(
          builder: (_) => MyBusinessProfileViewScreen(
            business: _approvedBusinesses.first,
          ),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const MyBusinessesScreen()),
    );
  }

  Future<void> _openMyProfessional() async {
    await Navigator.push(
      context,
      FirstVuePageRoute(builder: (_) => const MyProfessionalProfileViewScreen()),
    );
  }

  Widget _buildTabContent(String userId) {
    return switch (_selectedTab) {
      0 => ProfileMyPostsSection(
          refreshToken: _effectiveRefreshToken,
          embedded: true,
        ),
      1 => ProfileMediaSection(
          refreshToken: _effectiveRefreshToken,
          embedded: true,
        ),
      2 => PortfolioAlbumsSection(
          ownerType: PortfolioOwnerType.user,
          ownerId: userId,
          canManage: true,
        ),
      3 => ProfileAffiliationsSection(
          profileId: userId,
          showGroups: true,
          showCommunities: false,
          refreshToken: _effectiveRefreshToken,
        ),
      4 => ProfileAffiliationsSection(
          profileId: userId,
          showGroups: false,
          showCommunities: true,
          refreshToken: _effectiveRefreshToken,
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileSavedSection(refreshToken: widget.refreshToken),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Your about & saved items stay private to you unless you choose to share them.',
                style: TextStyle(
                  color: context.fv.secondaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final displayName = user == null
        ? 'Guest'
        : (_nameLoading
            ? (email.isEmpty ? '…' : email.split('@').first)
            : (_displayName ?? (email.isEmpty ? 'Guest' : email.split('@').first)));
    final handle = _username?.trim();
    final subtitle = user == null
        ? 'Sign in to sync your FirstVue account'
        : (handle != null && handle.isNotEmpty
            ? '@$handle'
            : (_showEmailOnProfile && email.isNotEmpty ? email : null));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: FirstVueSettingsDrawer(
        onSignOut: () {
          if (mounted) {
            setState(() {});
            _loadStats();
          }
        },
        onSignIn: () {
          if (mounted) setState(() {});
        },
      ),
      body: SafeArea(
        child: FirstVueRefreshScaffold(
        onRefresh: _refreshProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
          if (user != null)
            const FirstVueInlineSearchBar(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
            ),
          if (user != null)
            FollowRequestsSection(
              onChanged: () {
                _loadStats();
                setState(() => _pullRefreshToken++);
              },
            ),
          if (user != null) const LiveStreamEligibilityCard(),
          if (user != null &&
              !_nameLoading &&
              (handle == null || handle.isEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: FirstVueColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  onTap: _openEditProfile,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(
                    Icons.alternate_email,
                    color: FirstVueColors.gold,
                  ),
                  title: Text(
                    'Choose your @handle',
                    style: TextStyle(
                      color: context.fv.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Your tag must be unique. Display names can be shared.',
                    style: TextStyle(
                      color: context.fv.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: context.fv.mutedIcon,
                  ),
                ),
              ),
            ),
          Stack(
            children: [
              FacebookStyleProfileHeader(
                title: displayName,
                subtitle: subtitle,
                coverImageUrl: _profileImages.cover?.signedUrl,
                avatarImageUrl: _profileImages.avatar?.signedUrl,
                coverIsVideo: _profileImages.cover?.isVideo ?? false,
                avatarIsVideo: _profileImages.avatar?.isVideo ?? false,
                onCoverTap: _imageUpdating ? null : _showCoverOptions,
                onAvatarTap: _imageUpdating ? null : _showAvatarOptions,
                showImageLoading: _imagesLoading || _imageUpdating,
                stats: user == null
                    ? null
                    : [
                        ProfileStatItem(
                          label: 'Posts',
                          value: _statsLoading ? '—' : '${_stats.postCount}',
                        ),
                        ProfileStatItem(
                          label: 'Followers',
                          value: _statsLoading ? '—' : '$_followerCount',
                          onTap: () => _openFollowList(
                            FollowListMode.followers,
                            displayName,
                          ),
                        ),
                        ProfileStatItem(
                          label: 'Following',
                          value: _statsLoading ? '—' : '$_followingCount',
                          onTap: () => _openFollowList(
                            FollowListMode.following,
                            displayName,
                          ),
                        ),
                        ProfileStatItem(
                          label: 'Sparks',
                          value: _statsLoading ? '—' : '${_stats.sparksReceived}',
                        ),
                      ],
                actionButtons: user == null
                    ? [
                        FilledButton(
                          onPressed: () => _handleAccountTap(user),
                          style: FilledButton.styleFrom(
                            backgroundColor: FirstVueColors.gold,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Sign in or create account'),
                        ),
                      ]
                    : [
                        FilledButton(
                          onPressed: _openEditProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor: FirstVueColors.gold,
                            foregroundColor: const Color(0xFF17130B),
                          ),
                          child: const Text('Edit profile'),
                        ),
                        OutlinedButton(
                          onPressed: _shareProfile,
                          child: const Text('Share profile'),
                        ),
                        if (_approvedBusinesses.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: _openMyBusiness,
                            icon: const Icon(Icons.storefront_outlined, size: 18),
                            label: Text(
                              _approvedBusinesses.length == 1
                                  ? 'My Business'
                                  : 'My Businesses',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FirstVueColors.gold,
                            ),
                          ),
                        if (_hasApprovedProfessional)
                          OutlinedButton.icon(
                            onPressed: _openMyProfessional,
                            icon: const Icon(Icons.work_outline, size: 18),
                            label: const Text('My Professional'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: FirstVueColors.gold,
                            ),
                          ),
                      ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: Icon(
                    Icons.settings_outlined,
                    color: FirstVueColors.gold,
                  ),
                  tooltip: 'Settings',
                ),
              ),
            ],
          ),
          if (user != null) ...[
            const SizedBox(height: 12),
            UserProfileCompletionBanner(userId: user.id),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _tabLabels.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _ProfileTabButton(
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey(_selectedTab),
                child: _buildTabContent(user.id),
              ),
            ),
          ],
          if (user == null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilledButton(
                onPressed: () => _handleAccountTap(user),
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.gold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Sign in or create account'),
              ),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
      ),
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTabButton({
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selected ? 36 : 0,
                decoration: BoxDecoration(
                  color: FirstVueColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
