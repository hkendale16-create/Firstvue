import 'package:flutter/material.dart';
import '../navigation/firstvue_page_route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_rentals_screen.dart';
import 'admin_approvals_hub_screen.dart';
import 'admin_business_submissions_screen.dart';
import 'admin_business_reviews_screen.dart';
import 'admin_professional_profiles_screen.dart';
import 'auth_screen.dart';
import 'join_firstvue_screen.dart';
import 'business_growth_screen.dart';
import 'legal_policy_screen.dart';
import 'rental_inquiries_screen.dart';
import 'rentals_screen.dart';
import 'my_businesses_screen.dart';
import 'messages_inbox_screen.dart';
import 'my_professional_profile_view_screen.dart';
import '../services/admin_auth_service.dart';
import '../services/profile_media_service.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/profile_media_section.dart';
import '../widgets/profile_my_posts_section.dart';
import '../widgets/profile_recent_activity_section.dart';
import '../widgets/profile_saved_section.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
    _loadProfileImages();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadAdminAccess();
      _loadProfileImages();
    }
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
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white54),
                title: const Text('Remove profile photo', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeProfileImage(isAvatar: true);
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
            if (hasCover)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white54),
                title: const Text('Remove cover photo', style: TextStyle(color: Colors.white70)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      await _removeProfileImage(isAvatar: false);
    } else if (action == 'change') {
      await _changeProfileImage(isAvatar: false);
    }
  }

  Future<void> _changeProfileImage({required bool isAvatar}) async {
    final files = await showMediaPickerSheet(context);
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
    }
  }

  void _open(Widget screen) {
    Navigator.push(context, FirstVuePageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final displayName = email.isEmpty
        ? 'Guest'
        : email.split('@').first;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _imageUpdating ? null : _showCoverOptions,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: _profileImages.cover == null
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1A2530),
                              Color(0xFF243540),
                              Color(0xFF78B9BE),
                            ],
                          )
                        : null,
                    image: _profileImages.cover != null
                        ? DecorationImage(
                            image: NetworkImage(_profileImages.cover!.signedUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImages.cover == null && user != null
                      ? Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white.withValues(alpha: .45),
                              size: 22,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              if (_imagesLoading || _imageUpdating)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Positioned(
                left: 20,
                bottom: -36,
                child: GestureDetector(
                  onTap: _imageUpdating ? null : _showAvatarOptions,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: const Color(0xFF080B0F),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFF241D22),
                      backgroundImage: _profileImages.avatar != null
                          ? NetworkImage(_profileImages.avatar!.signedUrl)
                          : null,
                      child: _profileImages.avatar == null
                          ? Icon(
                              user == null ? Icons.person_outline : Icons.person,
                              color: const Color(0xFF78B9BE),
                              size: 40,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user == null
                      ? 'Sign in to sync your FirstVue account'
                      : email,
                  style: const TextStyle(color: Colors.white54),
                ),
                if (user != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _handleAccountTap(user),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: .2)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _handleAccountTap(user),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD8B56A),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Sign in or create account'),
                  ),
                ],
              ],
            ),
          ),
          if (user != null) ...[
            const SizedBox(height: 28),
            ProfileMediaSection(refreshToken: widget.refreshToken),
            ProfileSavedSection(refreshToken: widget.refreshToken),
            ProfileMyPostsSection(refreshToken: widget.refreshToken),
            ProfileRecentActivitySection(refreshToken: widget.refreshToken),
          ],
          const SizedBox(height: 10),
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
          const SizedBox(height: 28),
        ],
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
