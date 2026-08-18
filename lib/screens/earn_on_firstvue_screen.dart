import 'package:flutter/material.dart';

import '../auth/ensure_signed_in.dart';
import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/creator_earnings_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import 'bounty_discovery_screen.dart';
import 'business_campaign_dashboard_screen.dart';
import 'business_growth_screen.dart';
import 'create_bounty_draft_sheet.dart';
import 'creator_earnings_screen.dart';
import 'my_businesses_screen.dart';

/// Two-sided money hub: creators earn covering nights; venues pay for reach.
class EarnOnFirstVueScreen extends StatefulWidget {
  const EarnOnFirstVueScreen({super.key});

  @override
  State<EarnOnFirstVueScreen> createState() => _EarnOnFirstVueScreenState();
}

class _EarnOnFirstVueScreenState extends State<EarnOnFirstVueScreen> {
  bool _joining = false;

  Future<bool> _ensureAuth() async {
    if (!mounted) return false;
    return ensureSignedIn(context);
  }

  Future<void> _joinAsCreator() async {
    if (!await _ensureAuth()) return;
    setState(() => _joining = true);
    try {
      final prefs = await UserPreferencesService.fetch();
      await CreatorEarningsService.optInAsCreator(
        homeCity: prefs.locationCity,
        homeState: prefs.locationState,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You’re in. Browse bounties nearby to apply.'),
        ),
      );
      await Navigator.of(context).push(
        FirstVuePageRoute(builder: (_) => const BountyDiscoveryScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('StateError: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: fv.background,
      appBar: AppBar(
        title: const Text('Earn on FirstVue'),
        backgroundColor: fv.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Make money covering what’s going on.',
            style: TextStyle(
              color: fv.primaryText,
              fontFamily: 'CormorantGaramond',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Venues pay to get seen tonight. Creators get paid to show the night. '
            '${EarnMarketplace.splitLabel()}.',
            style: TextStyle(color: fv.secondaryText, height: 1.45),
          ),
          const SizedBox(height: 22),
          _SideCard(
            icon: Icons.videocam_outlined,
            accent: FirstVueColors.teal,
            title: 'For you',
            body:
                'Apply to VUE Bounties, cover a night nearby, and build creator '
                'reputation. Withdrawals stay off until payouts are approved — '
                'applications work now.',
            primaryLabel: _joining ? 'Joining…' : 'Become a creator',
            onPrimary: _joining ? null : _joinAsCreator,
            secondaryLabel: 'Browse bounties',
            onSecondary: () {
              Navigator.of(context).push(
                FirstVuePageRoute(
                  builder: (_) => const BountyDiscoveryScreen(),
                ),
              );
            },
            tertiaryLabel: 'My earnings',
            onTertiary: () {
              Navigator.of(context).push(
                FirstVuePageRoute(
                  builder: (_) => const CreatorEarningsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _SideCard(
            icon: Icons.storefront_outlined,
            accent: FirstVueColors.gold,
            title: 'For venues & organizers',
            body:
                'Hire creators to cover your night, then grow with Verified or Pro '
                'when checkout opens. Draft a bounty now — funding stays off '
                'until Stripe is live.',
            primaryLabel: 'Draft a bounty',
            onPrimary: () async {
              if (!await _ensureAuth()) return;
              if (!mounted) return;
              await CreateBountyDraftSheet.show(context);
            },
            secondaryLabel: 'Campaigns',
            onSecondary: () {
              Navigator.of(context).push(
                FirstVuePageRoute(
                  builder: (_) => const BusinessCampaignDashboardScreen(),
                ),
              );
            },
            tertiaryLabel: 'Plans & boosts',
            onTertiary: () {
              Navigator.of(context).push(
                FirstVuePageRoute(builder: (_) => const BusinessGrowthScreen()),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'HOW FIRSTVUE MAKES MONEY',
            style: TextStyle(
              color: FirstVueColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _HowRow(
            title: 'Venue plans',
            body: 'Verified and Pro for Tonight placement and boost credits.',
          ),
          _HowRow(
            title: 'Bounty marketplace',
            body: EarnMarketplace.splitLabel() +
                ' on creator campaigns. No wallet on the phone.',
          ),
          _HowRow(
            title: 'Boosts & tickets later',
            body:
                'Post boosts and paid Going stay flagged off until payments are approved.',
          ),
          if (!FeatureFlags.bountyFundingEnabled ||
              !FeatureFlags.creatorPayoutsEnabled) ...[
            const SizedBox(height: 16),
            Text(
              'Checkout, campaign funding, and withdrawals are not live in this build. '
              'Joining as a creator and drafting a bounty queues you for when they are.',
              style: TextStyle(color: fv.tertiaryText, fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                FirstVuePageRoute(builder: (_) => const MyBusinessesScreen()),
              );
            },
            child: const Text('Create or claim a business'),
          ),
        ],
      ),
    );
  }
}

class _HowRow extends StatelessWidget {
  final String title;
  final String body;

  const _HowRow({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle, color: FirstVueColors.gold, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$title · ',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: body,
                    style: TextStyle(color: fv.secondaryText, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String tertiaryLabel;
  final VoidCallback onTertiary;

  const _SideCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    required this.tertiaryLabel,
    required this.onTertiary,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fv.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: fv.primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: fv.secondaryText, height: 1.45)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              child: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel),
              ),
              TextButton(
                onPressed: onTertiary,
                child: Text(tertiaryLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
