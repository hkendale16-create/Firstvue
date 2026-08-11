import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_rentals_screen.dart';
import 'admin_business_submissions_screen.dart';
import 'admin_business_reviews_screen.dart';
import 'admin_professional_profiles_screen.dart';
import 'auth_screen.dart';
import 'business_owner_start_screen.dart';
import 'business_growth_screen.dart';
import 'legal_policy_screen.dart';
import 'rental_inquiries_screen.dart';
import 'rentals_screen.dart';
import 'my_businesses_screen.dart';
import 'messages_inbox_screen.dart';
import 'professional_profile_editor_screen.dart';
import '../services/admin_auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAdmin = false;
  bool _adminLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdminAccess();
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
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      await Supabase.instance.client.auth.signOut();
    }

    if (mounted) {
      setState(() {});
      await _loadAdminAccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;
    final displayName = email == null || email.isEmpty
        ? 'YOUR FIRSTVUE'
        : email.split('@').first.toUpperCase();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        children: [
          const Text(
            'PROFILE',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10151B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF78B9BE).withValues(alpha: .28),
              ),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFF241D22),
                  child: Icon(
                    Icons.person_outline,
                    color: Color(0xFF78B9BE),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email ?? 'Sign in to create your FirstVue profile',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'ACCOUNT',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _ProfileRow(
            icon: user == null ? Icons.login : Icons.logout,
            title: user == null ? 'Sign in or create an account' : 'Sign out',
            subtitle: user == null
                ? 'Use your secure FirstVue account'
                : 'Signed in as $email',
            onTap: () => _handleAccountTap(user),
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            subtitle: user == null
                ? 'Sign in to message business owners directly'
                : 'Direct conversations with owners and members',
            onTap: user == null
                ? () => _handleAccountTap(user)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MessagesInboxScreen(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.badge_outlined,
            title: 'My professional profile',
            subtitle: user == null
                ? 'Sign in to create your public professional identity'
                : 'Barbers, stylists, and beauty professionals',
            onTap: user == null
                ? () => _handleAccountTap(user)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfessionalProfileEditorScreen(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.edit_note_outlined,
            title: 'My business profiles',
            subtitle: user == null
                ? 'Sign in to manage your public details'
                : 'Add your about details and public address',
            onTap: user == null
                ? () => _handleAccountTap(user)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyBusinessesScreen(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.trending_up_rounded,
            title: 'Growth, plans & analytics',
            subtitle: user == null
                ? 'Sign in to access business monetization tools'
                : 'Pro plans, promotions, leads, bookings and performance',
            onTap: user == null
                ? () => _handleAccountTap(user)
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BusinessGrowthScreen(),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          if (_adminLoaded && _isAdmin) ...[
            _ProfileRow(
              icon: Icons.how_to_reg_outlined,
              title: 'Professional approvals',
              subtitle: 'FIRSTVUE administrator access only',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminProfessionalProfilesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ProfileRow(
              icon: Icons.verified_outlined,
              title: 'Business approvals',
              subtitle: 'FirstVue administrator access only',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminBusinessSubmissionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ProfileRow(
              icon: Icons.reviews_outlined,
              title: 'Review approvals',
              subtitle: 'FirstVue administrator access only',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminBusinessReviewsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            _ProfileRow(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Rental approvals',
              subtitle: 'FirstVue administrator access only',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminRentalsScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          _ProfileRow(
            icon: Icons.mark_email_unread_outlined,
            title: 'Rental inquiries',
            subtitle: user == null
                ? 'Sign in to view messages on your rentals'
                : 'Messages from interested professionals',
            onTap: user == null
                ? () => _handleAccountTap(user)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RentalInquiriesScreen(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.key_outlined,
            title: 'My rental listings',
            subtitle: user == null
                ? 'Sign in to view your listing statuses'
                : 'View pending, approved, and rejected rentals',
            onTap: user == null
                ? () => _handleAccountTap(user)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyRentalListingsScreen(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.location_on_outlined,
            title: 'Location preferences',
            subtitle: 'Controlled by your device permissions',
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.verified_user_outlined,
            title: 'Business owner tools',
            subtitle: 'Claim and verification are coming soon',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BusinessOwnerStartScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          const Text(
            'LEGAL',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _ProfileRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy policy',
            subtitle: 'How FirstVue handles your data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalPolicyScreen(
                  type: LegalPolicyType.privacy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.description_outlined,
            title: 'Terms of service',
            subtitle: 'Rules for using FirstVue',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalPolicyScreen(
                  type: LegalPolicyType.terms,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10151B),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFD8B56A)),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
