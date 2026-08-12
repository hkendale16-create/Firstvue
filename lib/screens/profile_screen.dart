import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_rentals_screen.dart';
import 'admin_approvals_hub_screen.dart';
import 'admin_business_submissions_screen.dart';
import 'admin_business_reviews_screen.dart';
import 'admin_professional_profiles_screen.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'join_firstvue_screen.dart';
import 'business_growth_screen.dart';
import 'legal_policy_screen.dart';
import 'rental_inquiries_screen.dart';
import 'rentals_screen.dart';
import 'my_businesses_screen.dart';
import 'messages_inbox_screen.dart';
import 'my_professional_profile_view_screen.dart';
import '../services/admin_auth_service.dart';
import '../services/community_news_service.dart';
import '../services/profile_media_service.dart';
import '../services/user_profile_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/facebook_style_profile_header.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/signed_media_viewer.dart' show openSignedMedia;
import '../widgets/profile_media_section.dart';
import '../widgets/profile_my_posts_section.dart';
import '../widgets/profile_recent_activity_section.dart';
import '../widgets/profile_saved_section.dart';
import '../widgets/firstvue_refresh_scaffold.dart';

class ProfileScreen extends StatefulWidget {
  final int refreshToken;

  const ProfileScreen({super.key, this.refreshToken = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAdmin = false;
  bool _adminLoaded = false;
  ProfileImageSet _profileImages = const ProfileImageSet();
  bool _imagesLoading = false;
  bool _imageUpdating = false;
  ProfileEngagementStats _stats = const ProfileEngagementStats(
    postCount: 0,
    sparksReceived: 0,
  );
  bool _statsLoading = false;
  String? _displayName;
  bool _nameLoading = false;
  int _selectedTab = 0;
  int _pullRefreshToken = 0;
  bool _showSettings = false;

  static const _tabLabels = ['POSTS', 'PHOTOS', 'ACTIVITY'];

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
    _loadProfileImages();
    _loadStats();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _displayName = null);
      return;
    }
    setState(() => _nameLoading = true);
    final name = await UserProfileService.fetchDisplayName();
    if (!mounted) return;
    setState(() {
      _displayName = name?.trim().isNotEmpty == true
          ? name!.trim()
          : user.email?.split('@').first;
      _nameLoading = false;
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadAdminAccess();
      _loadProfileImages();
      _loadStats();
      _loadDisplayName();
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
    final stats = await CommunityNewsService.fetchMyEngagementStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _statsLoading = false;
    });
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

  Future<void> _loadAdminAccess() async {
    final isAdmin = await AdminAuthService.isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _adminLoaded = true;
    });
  }

  Future<void> _handleAccountTap(User? user) async {
    if (user == null) {
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      await Supabase.instance.client.auth.signOut();
    }

    if (mounted) {
      setState(() {});
      await _loadAdminAccess();
      await _loadStats();
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, FirstVuePageRoute(builder: (_) => screen));
  }

  int get _effectiveRefreshToken => widget.refreshToken + _pullRefreshToken;

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadAdminAccess(),
      _loadProfileImages(),
      _loadStats(),
      _loadDisplayName(),
    ]);
    if (mounted) setState(() => _pullRefreshToken++);
  }

  void _shareProfilePlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile sharing is coming soon.')),
    );
  }

  Future<void> _openEditProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      await _handleAccountTap(null);
      return;
    }
    final updated = await Navigator.push<bool>(
      context,
      FirstVuePageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (updated == true && mounted) {
      await Future.wait([
        _loadDisplayName(),
        _loadProfileImages(),
      ]);
      setState(() => _pullRefreshToken++);
    }
  }

  Widget _buildTabContent() {
    return switch (_selectedTab) {
      0 => ProfileMyPostsSection(
          refreshToken: _effectiveRefreshToken,
          embedded: true,
        ),
      1 => ProfileMediaSection(
          refreshToken: _effectiveRefreshToken,
          embedded: true,
        ),
      _ => ProfileRecentActivitySection(
          refreshToken: _effectiveRefreshToken,
          embedded: true,
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

    return SafeArea(
      child: FirstVueRefreshScaffold(
        onRefresh: _refreshProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
          Stack(
            children: [
              FacebookStyleProfileHeader(
                title: displayName,
                subtitle: user == null
                    ? 'Sign in to sync your FirstVue account'
                    : email,
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
                          label: 'Sparks received',
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
                        OutlinedButton.icon(
                          onPressed: _openEditProfile,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: .25)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _shareProfilePlaceholder,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: .25)),
                          ),
                        ),
                      ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => setState(() => _showSettings = !_showSettings),
                  icon: Icon(
                    _showSettings ? Icons.close : Icons.settings_outlined,
                    color: Colors.white.withValues(alpha: .85),
                  ),
                  tooltip: _showSettings ? 'Hide settings' : 'Settings',
                ),
              ),
            ],
          ),
          if (user != null) ...[
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
                child: _buildTabContent(),
              ),
            ),
            if (_selectedTab == 0) ...[
              const SizedBox(height: 8),
              ProfileSavedSection(refreshToken: widget.refreshToken),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: OutlinedButton.icon(
                onPressed: () => _handleAccountTap(user),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: .2)),
                ),
              ),
            ),
          ],
          if (_showSettings || user == null) ...[
            const SizedBox(height: 16),
            _SettingsGroup(
              title: 'Your profile',
              children: [
                _SettingsTile(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Get verified',
                  subtitle: 'Business owner, professional, or organizer',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const JoinFirstVueScreen()),
                ),
                _SettingsTile(
                  icon: Icons.storefront_outlined,
                  title: 'My business profiles',
                  subtitle: 'Photos, address, menu & details',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const MyBusinessesScreen()),
                ),
                _SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'My professional profile',
                  subtitle: 'Individual barber or stylist profile',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const MyProfessionalProfileViewScreen()),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Activity',
              children: [
                _SettingsTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Messages',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const MessagesInboxScreen()),
                ),
                _SettingsTile(
                  icon: Icons.trending_up_rounded,
                  title: 'Growth, plans & analytics',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const BusinessGrowthScreen()),
                ),
                _SettingsTile(
                  icon: Icons.key_outlined,
                  title: 'My rental listings',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const MyRentalListingsScreen()),
                ),
                _SettingsTile(
                  icon: Icons.mark_email_unread_outlined,
                  title: 'Rental inquiries',
                  onTap: user == null
                      ? () => _handleAccountTap(user)
                      : () => _open(const RentalInquiriesScreen()),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Preferences',
              children: [
                _SettingsTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  subtitle: 'Controlled by device permissions',
                ),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Push alerts for messages & updates',
                ),
              ],
            ),
            if (_adminLoaded && _isAdmin)
              _SettingsGroup(
                title: 'Admin tools',
                titleColor: const Color(0xFFD8B56A),
                children: [
                  _SettingsTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Approval center',
                    subtitle: 'Business, professional & organizer',
                    onTap: () => _open(const AdminApprovalsHubScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.verified_outlined,
                    title: 'Business approvals',
                    onTap: () => _open(const AdminBusinessSubmissionsScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.how_to_reg_outlined,
                    title: 'Professional approvals',
                    onTap: () => _open(const AdminProfessionalProfilesScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.reviews_outlined,
                    title: 'Review approvals',
                    onTap: () => _open(const AdminBusinessReviewsScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Rental approvals',
                    onTap: () => _open(const AdminRentalsScreen()),
                  ),
                ],
              ),
            _SettingsGroup(
              title: 'Legal & support',
              children: [
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  onTap: () => _open(
                    const LegalPolicyScreen(type: LegalPolicyType.privacy),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of service',
                  onTap: () => _open(
                    const LegalPolicyScreen(type: LegalPolicyType.terms),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
        ],
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
                  color: selected ? FirstVueColors.gold : Colors.white54,
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

class _SettingsGroup extends StatelessWidget {
  final String title;
  final Color? titleColor;
  final List<Widget> children;

  const _SettingsGroup({
    required this.title,
    required this.children,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: titleColor ?? Colors.white54,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF10151B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFD8B56A), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
