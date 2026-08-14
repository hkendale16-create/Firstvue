import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../navigation/firstvue_page_route.dart';
import '../screens/admin_approvals_hub_screen.dart';
import '../screens/admin_business_reviews_screen.dart';
import '../screens/admin_business_submissions_screen.dart';
import '../screens/admin_professional_profiles_screen.dart';
import '../screens/admin_rentals_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/business_growth_screen.dart';
import '../screens/join_firstvue_screen.dart';
import '../screens/legal_policy_screen.dart';
import '../screens/messages_inbox_screen.dart';
import '../screens/my_businesses_screen.dart';
import '../screens/my_professional_profile_view_screen.dart';
import '../screens/rental_inquiries_screen.dart';
import '../screens/rentals_screen.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/entity_settings_screen.dart';
import '../screens/privacy_settings_screen.dart';
import '../screens/settings_preferences_screen.dart';
import '../services/admin_auth_service.dart';
import '../theme/firstvue_theme.dart';

typedef FirstVueSettingsOpen = void Function(Widget screen);

/// Full-screen Settings shell (replaces the clipped end drawer).
class SettingsShellScreen extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;

  const SettingsShellScreen({super.key, this.onSignOut, this.onSignIn});

  @override
  State<SettingsShellScreen> createState() => _SettingsShellScreenState();
}

class FirstVueSettingsDrawer extends SettingsShellScreen {
  const FirstVueSettingsDrawer({super.key, super.onSignOut, super.onSignIn});
}

class _SettingsShellScreenState extends State<SettingsShellScreen> {
  bool _isAdmin = false;
  bool _adminLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    final isAdmin = await AdminAuthService.isAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _adminLoaded = true;
    });
  }

  void _open(Widget screen) {
    Navigator.push(context, FirstVuePageRoute(builder: (_) => screen));
  }

  Future<void> _handleAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      widget.onSignIn?.call();
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      await Supabase.instance.client.auth.signOut();
      widget.onSignOut?.call();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fv = context.fv;

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: const Text('Settings'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SettingsGroup(
                title: 'Your profile',
                children: [
                  _SettingsTile(
                    icon: Icons.settings_suggest_outlined,
                    title: 'Entity settings',
                    subtitle: 'Profile, media, privacy, groups & more',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const EntitySettingsScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline,
                    title: 'Privacy',
                    subtitle: 'Visibility & field controls',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const PrivacySettingsScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.how_to_reg_outlined,
                    title: 'Get verified',
                    subtitle: 'Business owner, professional, or organizer',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const JoinFirstVueScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.storefront_outlined,
                    title: 'My business profiles',
                    subtitle: 'Photos, address, menu & details',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const MyBusinessesScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.badge_outlined,
                    title: 'My professional profile',
                    subtitle: 'Individual barber or stylist profile',
                    onTap: user == null
                        ? _handleAccount
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
                        ? _handleAccount
                        : () => _open(const MessagesInboxScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.trending_up_rounded,
                    title: 'Growth, plans & analytics',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const BusinessGrowthScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.key_outlined,
                    title: 'My rental listings',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const MyRentalListingsScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Rental inquiries',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const RentalInquiriesScreen()),
                  ),
                ],
              ),
              _SettingsGroup(
                title: 'Preferences',
                children: [
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Light, Dark, or System Default',
                    onTap: () => _open(const AppearanceSettingsScreen()),
                  ),
                  _SettingsTile(
                    icon: Icons.tune_outlined,
                    title: 'Location & notifications',
                    subtitle: 'City, alerts & floating messages bubble',
                    onTap: user == null
                        ? _handleAccount
                        : () => _open(const SettingsPreferencesScreen()),
                  ),
                ],
              ),
              if (_adminLoaded && _isAdmin)
                _SettingsGroup(
                  title: 'Admin tools',
                  titleColor: FirstVueColors.gold,
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
                      onTap: () =>
                          _open(const AdminBusinessSubmissionsScreen()),
                    ),
                    _SettingsTile(
                      icon: Icons.how_to_reg_outlined,
                      title: 'Professional approvals',
                      onTap: () =>
                          _open(const AdminProfessionalProfilesScreen()),
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
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _handleAccount,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fv.secondaryText,
                      side: BorderSide(color: fv.borderSubtle),
                    ),
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
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: titleColor ?? fv.tertiaryText,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: fv.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fv.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(height: 1, indent: 56, color: fv.divider),
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
    final fv = context.fv;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        subtitle!,
                        style: TextStyle(color: fv.secondaryText, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: fv.tertiaryText, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
