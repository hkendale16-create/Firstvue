import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/admin_auth_service.dart';
import '../theme/firstvue_theme.dart';
import 'admin_approvals_hub_screen.dart';
import 'appearance_settings_screen.dart';
import 'communities_screen.dart';
import 'create_community_hub_screen.dart';
import 'create_community_screen.dart';
import 'edit_profile_screen.dart';
import 'join_firstvue_screen.dart';
import 'my_businesses_screen.dart';
import 'my_professional_profile_view_screen.dart';
import 'privacy_settings_screen.dart';
import 'profile_screen.dart';
import 'rentals_screen.dart';
import 'settings_preferences_screen.dart';

/// Modern borderless FirstVue entity settings hub.
class EntitySettingsScreen extends StatefulWidget {
  const EntitySettingsScreen({super.key});

  @override
  State<EntitySettingsScreen> createState() => _EntitySettingsScreenState();
}

class _EntitySettingsScreenState extends State<EntitySettingsScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final isAdmin = await AdminAuthService.isAdmin();
    if (!mounted) return;
    setState(() => _isAdmin = isAdmin);
  }

  void _open(Widget screen) {
    Navigator.push(context, FirstVuePageRoute(builder: (_) => screen));
  }

  Future<void> _requireAuthThen(VoidCallback action) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to manage entity settings.')),
      );
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Entity settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Manage profile, business, media, privacy, and community settings '
            'in one place.',
            style: TextStyle(color: fv.secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _section(
            title: 'Profile',
            children: [
              _tile(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Name, handle, bio, location & links',
                onTap: () => _requireAuthThen(
                  () => _open(const EditProfileScreen()),
                ),
              ),
              _tile(
                icon: Icons.badge_outlined,
                title: 'View my profile',
                onTap: () => _requireAuthThen(
                  () => _open(const ProfileScreen()),
                ),
              ),
              _tile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Light, Dark, or System Default',
                onTap: () => _open(const AppearanceSettingsScreen()),
              ),
            ],
          ),
          _section(
            title: 'Business Information',
            children: [
              _tile(
                icon: Icons.storefront_outlined,
                title: 'My business profiles',
                subtitle: 'Photos, address, menu & details',
                onTap: () => _requireAuthThen(
                  () => _open(const MyBusinessesScreen()),
                ),
              ),
              _tile(
                icon: Icons.work_outline,
                title: 'My professional profile',
                subtitle: 'Individual barber or stylist profile',
                onTap: () => _requireAuthThen(
                  () => _open(const MyProfessionalProfileViewScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Contact',
            children: [
              _tile(
                icon: Icons.edit_outlined,
                title: 'Contact details',
                subtitle: 'Phone & website via Edit profile',
                onTap: () => _requireAuthThen(
                  () => _open(const EditProfileScreen()),
                ),
              ),
              _tile(
                icon: Icons.privacy_tip_outlined,
                title: 'Email visibility',
                subtitle: 'Managed in Privacy settings',
                onTap: () => _requireAuthThen(
                  () => _open(const PrivacySettingsScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Location',
            children: [
              _tile(
                icon: Icons.location_on_outlined,
                title: 'Profile location',
                subtitle: 'City & state on your profile',
                onTap: () => _requireAuthThen(
                  () => _open(const EditProfileScreen()),
                ),
              ),
              _tile(
                icon: Icons.tune_outlined,
                title: 'Preferred discovery location',
                subtitle: 'City used for nearby results',
                onTap: () => _requireAuthThen(
                  () => _open(const SettingsPreferencesScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Media & Portfolio',
            children: [
              _tile(
                icon: Icons.photo_library_outlined,
                title: 'Profile media',
                subtitle: 'Avatar, cover & albums from your profile',
                onTap: () => _requireAuthThen(
                  () => _open(const ProfileScreen()),
                ),
              ),
              _tile(
                icon: Icons.store_mall_directory_outlined,
                title: 'Business media',
                subtitle: 'Photos & portfolio on business profiles',
                onTap: () => _requireAuthThen(
                  () => _open(const MyBusinessesScreen()),
                ),
              ),
              _tile(
                icon: Icons.content_cut_outlined,
                title: 'Professional media',
                subtitle: 'Portfolio on your professional profile',
                onTap: () => _requireAuthThen(
                  () => _open(const MyProfessionalProfileViewScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Privacy',
            children: [
              _tile(
                icon: Icons.lock_outline,
                title: 'Privacy settings',
                subtitle: 'Profile & field visibility',
                onTap: () => _requireAuthThen(
                  () => _open(const PrivacySettingsScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Permissions',
            children: [
              _tile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Role & access',
                subtitle: 'Verification unlocks owner tools',
                onTap: () => _requireAuthThen(
                  () => _open(const JoinFirstVueScreen()),
                ),
              ),
              if (_isAdmin)
                _tile(
                  icon: Icons.verified_user_outlined,
                  title: 'Admin approvals',
                  subtitle: 'Business, professional & organizer',
                  onTap: () => _open(const AdminApprovalsHubScreen()),
                ),
            ],
          ),
          _section(
            title: 'Notifications',
            children: [
              _tile(
                icon: Icons.notifications_outlined,
                title: 'Alerts & sounds',
                subtitle: 'Push notifications & interaction sounds',
                onTap: () => _requireAuthThen(
                  () => _open(const SettingsPreferencesScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Verification',
            children: [
              _tile(
                icon: Icons.how_to_reg_outlined,
                title: 'Get verified',
                subtitle: 'Business owner, professional, or organizer',
                onTap: () => _requireAuthThen(
                  () => _open(const JoinFirstVueScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Groups & Communities',
            children: [
              _tile(
                icon: Icons.groups_outlined,
                title: 'Browse groups & communities',
                onTap: () => _requireAuthThen(
                  () => _open(const CommunitiesScreen(allowCreate: true)),
                ),
              ),
              _tile(
                icon: Icons.group_add_outlined,
                title: 'Create a group',
                onTap: () => _requireAuthThen(
                  () => _open(const CreateCommunityScreen()),
                ),
              ),
              _tile(
                icon: Icons.hub_outlined,
                title: 'Create a community hub',
                onTap: () => _requireAuthThen(
                  () => _open(const CreateCommunityHubScreen()),
                ),
              ),
            ],
          ),
          _section(
            title: 'Advanced',
            children: [
              _tile(
                icon: Icons.key_outlined,
                title: 'My rental listings',
                onTap: () => _requireAuthThen(
                  () => _open(const MyRentalListingsScreen()),
                ),
              ),
              _tile(
                icon: Icons.tune_outlined,
                title: 'Preferences',
                subtitle: 'Location, notifications & bubble',
                onTap: () => _requireAuthThen(
                  () => _open(const SettingsPreferencesScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          ...[
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(height: 1, color: fv.divider),
            ],
          ],
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: FirstVueColors.gold, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fv.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: fv.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fv.tertiaryText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
