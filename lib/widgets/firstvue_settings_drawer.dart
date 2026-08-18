import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_session_controller.dart';
import '../config/feature_flags.dart';
import '../navigation/firstvue_page_route.dart';
import '../screens/about_firstvue_screen.dart';
import '../screens/admin_business_reviews_screen.dart';
import '../screens/admin_business_submissions_screen.dart';
import '../screens/admin_early_access_screen.dart';
import '../screens/admin_professional_profiles_screen.dart';
import '../screens/admin_rentals_screen.dart';
import '../screens/admin_approvals_hub_screen.dart';
import '../screens/admin_financial_controls_screen.dart';
import '../screens/bounty_discovery_screen.dart';
import '../screens/business_campaign_dashboard_screen.dart';
import '../screens/business_growth_screen.dart';
import '../screens/creator_earnings_screen.dart';
import '../screens/earn_on_firstvue_screen.dart';
import '../screens/help_build_firstvue_screen.dart';
import '../screens/join_firstvue_screen.dart';
import '../screens/legal_policy_screen.dart';
import '../screens/messages_inbox_screen.dart';
import '../screens/my_businesses_screen.dart';
import '../screens/my_professional_profile_view_screen.dart';
import '../screens/rental_inquiries_screen.dart';
import '../screens/rentals_screen.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/create_community_hub_screen.dart';
import '../screens/create_community_screen.dart';
import '../screens/entity_settings_screen.dart';
import '../screens/event_planner_screen.dart';
import '../screens/privacy_settings_screen.dart';
import '../screens/settings_preferences_screen.dart';
import '../navigation/entity_navigation.dart';
import '../services/admin_auth_service.dart';
import '../theme/firstvue_theme.dart';
import 'early_access_badge.dart';
import 'firstvue_onboarding.dart';
import 'firstvue_section_tip.dart';
import 'invite_friends_sheet.dart';
import 'tutorial_targets.dart';
import '../services/onboarding_store.dart';

typedef FirstVueSettingsOpen = void Function(Widget screen);

/// Full-screen Settings shell (replaces the clipped end drawer).
class SettingsShellScreen extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;

  static const routeName = '/settings';

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
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAdmin();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowSectionTip(context, TutorialSection.settings);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesTile(String title, [String? subtitle, String? group]) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (group != null && group.toLowerCase().contains(q)) return true;
    if (title.toLowerCase().contains(q)) return true;
    return subtitle?.toLowerCase().contains(q) ?? false;
  }

  Widget? _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Key? key,
    String? group,
  }) {
    if (!_matchesTile(title, subtitle, group)) return null;
    return _SettingsTile(
      key: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Widget? _group({
    required String title,
    required List<Widget?> tiles,
    Color? titleColor,
    Key? key,
  }) {
    final children = tiles.whereType<Widget>().toList(growable: false);
    if (children.isEmpty) return null;
    return _SettingsGroup(
      key: key,
      title: title,
      titleColor: titleColor,
      children: children,
    );
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
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
      return;
    }
    await authSessionController.signOut();
    widget.onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fv = context.fv;

    const earlyAccessGroup = 'Early Access';
    const profileGroup = 'Your profile';
    const groupsGroup = 'Groups & communities';
    const activityGroup = 'Activity';
    const monetizationGroup = 'Monetization';
    const listingsGroup = 'Listings';
    const preferencesGroup = 'Preferences';
    const helpGroup = 'Help / Tutorial';
    const adminGroup = 'Admin tools';
    const legalGroup = 'Legal & support';

    final sections = <Widget?>[
      _group(
        title: earlyAccessGroup,
        tiles: [
          _tile(
            group: earlyAccessGroup,
            icon: Icons.chat_bubble_outline,
            title: 'Send feedback',
            subtitle: 'Bugs, ideas, confusion & what’s missing near you',
            onTap: user == null
                ? _handleAccount
                : () => _open(const HelpBuildFirstVueScreen()),
          ),
        ],
      ),
      _group(
        title: profileGroup,
        tiles: [
          _tile(
            group: profileGroup,
            icon: Icons.settings_suggest_outlined,
            title: 'Entity settings',
            subtitle: 'Profile, media, privacy, groups & more',
            onTap: user == null
                ? _handleAccount
                : () => _open(const EntitySettingsScreen()),
          ),
          _tile(
            group: profileGroup,
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Visibility & field controls',
            onTap: user == null
                ? _handleAccount
                : () => _open(const PrivacySettingsScreen()),
          ),
          _tile(
            group: profileGroup,
            key: TutorialTargets.settingsVerified,
            icon: Icons.how_to_reg_outlined,
            title: 'Get verified',
            subtitle: 'Business owner, professional, or organizer',
            onTap: user == null
                ? _handleAccount
                : () => _open(const JoinFirstVueScreen()),
          ),
          _tile(
            group: profileGroup,
            icon: Icons.storefront_outlined,
            title: 'My business profiles',
            subtitle: 'Photos, address, menu & details',
            onTap: user == null
                ? _handleAccount
                : () => _open(const MyBusinessesScreen()),
          ),
          _tile(
            group: profileGroup,
            icon: Icons.badge_outlined,
            title: 'My professional profile',
            subtitle: 'Individual barber or stylist profile',
            onTap: user == null
                ? _handleAccount
                : () => _open(const MyProfessionalProfileViewScreen()),
          ),
        ],
      ),
      _group(
        title: groupsGroup,
        tiles: [
          _tile(
            group: groupsGroup,
            icon: Icons.group_add_outlined,
            title: 'Create group',
            subtitle: 'Start a public or private group',
            onTap: user == null
                ? _handleAccount
                : () => _open(const CreateCommunityScreen()),
          ),
          _tile(
            group: groupsGroup,
            icon: Icons.hub_outlined,
            title: 'Create community',
            subtitle: 'Start a community hub for your city',
            onTap: user == null
                ? _handleAccount
                : () => _open(const CreateCommunityHubScreen()),
          ),
          _tile(
            group: groupsGroup,
            icon: Icons.groups_outlined,
            title: 'Browse groups & communities',
            subtitle: 'Discover, join, and manage yours',
            onTap: () => EntityNavigation.openCommunitiesBrowse(
              context,
              allowCreate: user != null,
            ),
          ),
        ],
      ),
      _group(
        title: activityGroup,
        tiles: [
          _tile(
            group: activityGroup,
            icon: Icons.event_note_outlined,
            title: 'Event Planner',
            subtitle: 'Create & manage your events',
            onTap: user == null
                ? _handleAccount
                : () => _open(const EventPlannerScreen()),
          ),
          _tile(
            group: activityGroup,
            icon: Icons.person_add_alt_1_outlined,
            title: 'Invite friends',
            subtitle: 'Share FirstVue with people you know',
            onTap: user == null
                ? _handleAccount
                : () => InviteFriendsSheet.show(context),
          ),
          _tile(
            group: activityGroup,
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            onTap: user == null
                ? _handleAccount
                : () => _open(const MessagesInboxScreen()),
          ),
        ],
      ),
      _group(
        key: TutorialTargets.settingsMonetization,
        title: monetizationGroup,
        tiles: [
          _tile(
            group: monetizationGroup,
            icon: Icons.payments_outlined,
            title: 'Earn on FirstVue',
            subtitle: 'Creators cover nights · venues hire and grow',
            onTap: user == null
                ? _handleAccount
                : () => _open(const EarnOnFirstVueScreen()),
          ),
          _tile(
            group: monetizationGroup,
            icon: Icons.workspace_premium_outlined,
            title: 'Monetization & Plans',
            subtitle: FeatureFlags.effectiveBusinessSubscriptions
                ? 'Business plans, boosts & analytics'
                : 'Plan previews — payments coming soon',
            onTap: user == null
                ? _handleAccount
                : () => _open(const BusinessGrowthScreen()),
          ),
          if (FeatureFlags.vueBountiesEnabled) ...[
            _tile(
              group: monetizationGroup,
              icon: Icons.local_fire_department_outlined,
              title: 'VUE Bounties',
              subtitle: 'Discover creator campaigns nearby',
              onTap: user == null
                  ? _handleAccount
                  : () => _open(const BountyDiscoveryScreen()),
            ),
            _tile(
              group: monetizationGroup,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Creator earnings',
              subtitle: 'Applications, pending & history',
              onTap: user == null
                  ? _handleAccount
                  : () => _open(const CreatorEarningsScreen()),
            ),
            _tile(
              group: monetizationGroup,
              icon: Icons.campaign_outlined,
              title: 'Campaign dashboard',
              subtitle: 'Business bounty results',
              onTap: user == null
                  ? _handleAccount
                  : () => _open(const BusinessCampaignDashboardScreen()),
            ),
          ],
        ],
      ),
      _group(
        title: listingsGroup,
        tiles: [
          _tile(
            group: listingsGroup,
            icon: Icons.key_outlined,
            title: 'My rental listings',
            onTap: user == null
                ? _handleAccount
                : () => _open(const MyRentalListingsScreen()),
          ),
          _tile(
            group: listingsGroup,
            icon: Icons.mark_email_unread_outlined,
            title: 'Rental inquiries',
            onTap: user == null
                ? _handleAccount
                : () => _open(const RentalInquiriesScreen()),
          ),
        ],
      ),
      _group(
        title: preferencesGroup,
        tiles: [
          _tile(
            group: preferencesGroup,
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Light, Dark, or System Default',
            onTap: () => _open(const AppearanceSettingsScreen()),
          ),
          _tile(
            group: preferencesGroup,
            icon: Icons.tune_outlined,
            title: 'Location & notifications',
            subtitle: 'City, alerts & floating messages bubble',
            onTap: user == null
                ? _handleAccount
                : () => _open(const SettingsPreferencesScreen()),
          ),
        ],
      ),
      _group(
        title: helpGroup,
        tiles: [
          _tile(
            group: helpGroup,
            icon: Icons.menu_book_outlined,
            title: 'View Tutorial Again',
            subtitle: 'Replay short tips for every section',
            onTap: () => showOnboardingTourReplay(context),
          ),
          _tile(
            group: helpGroup,
            icon: Icons.chat_bubble_outline,
            title: 'Send feedback',
            subtitle: 'Bugs, ideas & what\'s missing near you',
            onTap: user == null
                ? _handleAccount
                : () => _open(const HelpBuildFirstVueScreen()),
          ),
        ],
      ),
      if (_adminLoaded && _isAdmin)
        _group(
          title: adminGroup,
          titleColor: FirstVueColors.gold,
          tiles: [
            _tile(
              group: adminGroup,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Approval center',
              subtitle: 'Business, professional & organizer',
              onTap: () => _open(const AdminApprovalsHubScreen()),
            ),
            _tile(
              group: adminGroup,
              icon: Icons.verified_outlined,
              title: 'Business approvals',
              onTap: () => _open(const AdminBusinessSubmissionsScreen()),
            ),
            _tile(
              group: adminGroup,
              icon: Icons.how_to_reg_outlined,
              title: 'Professional approvals',
              onTap: () => _open(const AdminProfessionalProfilesScreen()),
            ),
            _tile(
              group: adminGroup,
              icon: Icons.reviews_outlined,
              title: 'Review approvals',
              onTap: () => _open(const AdminBusinessReviewsScreen()),
            ),
            _tile(
              group: adminGroup,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Rental approvals',
              onTap: () => _open(const AdminRentalsScreen()),
            ),
            _tile(
              group: adminGroup,
              icon: Icons.insights_outlined,
              title: 'Early Access',
              subtitle: 'Feedback, ideas & founding members',
              onTap: () => _open(const AdminEarlyAccessScreen()),
            ),
            _tile(
              group: adminGroup,
              icon: Icons.account_balance_outlined,
              title: 'Financial controls',
              subtitle: 'Campaigns, ledger, disputes, risk',
              onTap: () => _open(const AdminFinancialControlsScreen()),
            ),
          ],
        ),
      _group(
        title: legalGroup,
        tiles: [
          _tile(
            group: legalGroup,
            icon: Icons.info_outline,
            title: 'About FirstVue',
            subtitle: 'Early Access & app version',
            onTap: () => _open(const AboutFirstVueScreen()),
          ),
          _tile(
            group: legalGroup,
            icon: Icons.chat_bubble_outline,
            title: 'Send feedback',
            subtitle: 'Help shape Early Access',
            onTap: user == null
                ? _handleAccount
                : () => _open(const HelpBuildFirstVueScreen()),
          ),
          _tile(
            group: legalGroup,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy policy',
            onTap: () => _open(
              const LegalPolicyScreen(type: LegalPolicyType.privacy),
            ),
          ),
          _tile(
            group: legalGroup,
            icon: Icons.description_outlined,
            title: 'Terms of service',
            onTap: () => _open(
              const LegalPolicyScreen(type: LegalPolicyType.terms),
            ),
          ),
        ],
      ),
    ];

    final visibleSections = sections.whereType<Widget>().toList(growable: false);

    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        backgroundColor: fv.background,
        foregroundColor: fv.primaryText,
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: fv.primaryText),
                cursorColor: FirstVueColors.gold,
                decoration: InputDecoration(
                  hintText: 'Search settings',
                  hintStyle: TextStyle(color: fv.tertiaryText),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('Settings'),
        actions: [
          IconButton(
            tooltip: _searchOpen ? 'Close search' : 'Search settings',
            onPressed: _toggleSearch,
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              if (!_searchOpen)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 14),
                  child: Row(
                    children: [
                      Text(
                        'FirstVue',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          color: fv.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      EarlyAccessBadge(
                        compact: true,
                        onTap: user == null
                            ? _handleAccount
                            : () => _open(const HelpBuildFirstVueScreen()),
                      ),
                    ],
                  ),
                ),
              ...visibleSections,
              if (_searchQuery.trim().isNotEmpty && visibleSections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        color: fv.tertiaryText,
                        size: 36,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No matching settings',
                        style: TextStyle(color: fv.secondaryText),
                      ),
                    ],
                  ),
                ),
              if (user != null && _searchQuery.trim().isEmpty)
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
    super.key,
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
    super.key,
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
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fv.elevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: fv.borderSubtle),
                ),
                child: Icon(icon, color: FirstVueColors.gold, size: 20),
              ),
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
