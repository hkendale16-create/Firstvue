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
import '../screens/settings_preferences_screen.dart';
import '../services/admin_auth_service.dart';
import '../theme/firstvue_theme.dart';

typedef FirstVueSettingsOpen = void Function(Widget screen);

class FirstVueSettingsDrawer extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;

  const FirstVueSettingsDrawer({
    super.key,
    this.onSignOut,
    this.onSignIn,
  });

  @override
  State<FirstVueSettingsDrawer> createState() => _FirstVueSettingsDrawerState();
}

class _FirstVueSettingsDrawerState extends State<FirstVueSettingsDrawer> {
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
    Navigator.pop(context);
    Navigator.push(context, FirstVuePageRoute(builder: (_) => screen));
  }

  Future<void> _handleAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    Navigator.pop(context);
    if (user == null) {
      widget.onSignIn?.call();
      await Navigator.push(
        context,
        FirstVuePageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      await Supabase.instance.client.auth.signOut();
      widget.onSignOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Drawer(
      backgroundColor: const Color(0xFF080B0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: FirstVueColors.gold,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SettingsGroup(
              title: 'Your profile',
              children: [
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
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton.icon(
                  onPressed: _handleAccount,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: .2)),
                  ),
                ),
              ),
          ],
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
      padding: const EdgeInsets.only(bottom: 18),
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
              Icon(icon, color: FirstVueColors.gold, size: 22),
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
