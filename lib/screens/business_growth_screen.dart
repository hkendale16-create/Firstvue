import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/business_submission_service.dart';
import '../services/business_subscription_service.dart';
import '../services/monetization_products_service.dart';
import '../services/stripe_billing_service.dart';
import '../theme/firstvue_theme.dart';
import 'business_campaign_dashboard_screen.dart';
import 'create_bounty_draft_sheet.dart';
import 'my_businesses_screen.dart';

class BusinessGrowthScreen extends StatefulWidget {
  const BusinessGrowthScreen({super.key});

  @override
  State<BusinessGrowthScreen> createState() => _BusinessGrowthScreenState();
}

class _BusinessGrowthScreenState extends State<BusinessGrowthScreen> {
  late Future<_GrowthData> _data = _load();
  String? _selectedBusinessId;
  bool _checkoutLoading = false;

  Future<_GrowthData> _load() async {
    final businesses = await BusinessSubmissionService.fetchMyBusinesses();
    final subscriptions = await BusinessSubscriptionService.fetchForBusinesses(
      businesses.map((business) => business.id),
    );
    final products = await MonetizationProductsService.fetchProducts();
    MonetizationProduct verified = MonetizationProductCatalog.fallbackById(
      MonetizationProductIds.businessVerified,
    );
    MonetizationProduct pro = MonetizationProductCatalog.fallbackById(
      MonetizationProductIds.businessPro,
    );
    for (final p in products) {
      if (p.id == MonetizationProductIds.businessVerified) verified = p;
      if (p.id == MonetizationProductIds.businessPro) pro = p;
    }
    return _GrowthData(
      businesses: businesses,
      subscriptions: subscriptions,
      verifiedProduct: verified,
      proProduct: pro,
    );
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
  }

  void _ensureSelection(List<OwnedBusiness> businesses) {
    if (businesses.isEmpty) return;
    final stillValid = businesses.any((b) => b.id == _selectedBusinessId);
    if (_selectedBusinessId == null || !stillValid) {
      // Defer setState so we never mutate during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedBusinessId = businesses.first.id);
      });
    }
  }

  Future<void> _subscribe(BusinessPlan plan) async {
    final businessId = _selectedBusinessId;
    if (businessId == null) {
      _showMessage('Select a business before upgrading.');
      return;
    }

    setState(() => _checkoutLoading = true);
    try {
      final url = await StripeBillingService.startSubscriptionCheckout(
        businessId: businessId,
        plan: plan,
      );
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, webOnlyWindowName: '_self');
      if (!launched && mounted) {
        _showMessage('Could not open Stripe checkout.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('StateError: ', ''));
      }
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showComingSoon(String feature) {
    _showMessage('$feature — payments coming soon during Early Access.');
  }

  void _openCampaignDashboard() {
    Navigator.of(context).push(
      FirstVuePageRoute(
        builder: (_) => const BusinessCampaignDashboardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Monetization & Plans'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_GrowthData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load business growth tools.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: fv.secondaryText),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final businesses = data.businesses;

          if (businesses.isEmpty) {
            final verifiedPrice = data.verifiedProduct.priceLabel;
            final proPrice = data.proProduct.priceLabel;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Monetization & Plans',
                  style: TextStyle(
                    color: fv.primaryText,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You don’t have a business profile yet — that’s why plan tools '
                  'looked missing. Preview plans below, then create or claim a '
                  'business to manage upgrades. Personal creators can still use '
                  'Boost Post on their own posts.',
                  style: TextStyle(color: fv.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: fv.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FirstVueColors.gold.withValues(alpha: .35),
                    ),
                  ),
                  child: Text(
                    'Payments coming soon — plan previews are available, but '
                    'Stripe checkout stays disabled during Early Access.',
                    style: TextStyle(color: fv.secondaryText, height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        FirstVuePageRoute(
                          builder: (_) => const MyBusinessesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Create or manage a business'),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'PLAN PREVIEWS',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  name: 'BASIC',
                  price: 'FREE',
                  features: 'Business listing • Services • Photos • Reviews',
                  isCurrent: true,
                  isLoading: false,
                  actionLabel: null,
                  onAction: null,
                  onTap: () => _showMessage(
                    'Basic is your free listing plan — always available.',
                  ),
                ),
                _PlanCard(
                  name: 'VERIFIED',
                  price: verifiedPrice,
                  features: 'Verified badge • Trust tools • Owner identity',
                  isCurrent: false,
                  isLoading: false,
                  actionLabel: 'COMING SOON',
                  onAction: () => _showComingSoon('Verified'),
                  onTap: () => _showComingSoon('Verified'),
                ),
                _PlanCard(
                  name: 'FIRSTVUE PRO',
                  price: proPrice,
                  features: 'Analytics • Lead insights • Campaign tools',
                  isCurrent: false,
                  isLoading: false,
                  actionLabel: 'COMING SOON',
                  onAction: () => _showComingSoon('FirstVue Pro'),
                  onTap: () => _showComingSoon('FirstVue Pro'),
                ),
                const SizedBox(height: 12),
                Text(
                  'BOOST POST TIERS',
                  style: TextStyle(
                    color: FirstVueColors.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                for (final tier in MonetizationProductCatalog.postBoostTiers())
                  _Tool(
                    icon: Icons.rocket_launch_outlined,
                    title: '${tier.displayName} · ${tier.priceLabel}',
                    subtitle:
                        'Draft from your post menu (•••). Payments not active yet.',
                    onTap: () => _showComingSoon(tier.displayName),
                  ),
              ],
            );
          }

          _ensureSelection(businesses);
          final selectedId = _selectedBusinessId ?? businesses.first.id;
          final selected = businesses.firstWhere(
            (business) => business.id == selectedId,
            orElse: () => businesses.first,
          );
          final subscription = data.subscriptions[selectedId];
          final paymentsEnabled = FeatureFlags.effectiveBusinessSubscriptions;
          final verifiedPrice = data.verifiedProduct.priceLabel;
          final proPrice = data.proProduct.priceLabel;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Turn attention into customers',
                style: TextStyle(
                  color: fv.primaryText,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Managing growth for ${selected.name}',
                style: TextStyle(color: fv.secondaryText),
              ),
              const SizedBox(height: 16),
              if (!paymentsEnabled) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: fv.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FirstVueColors.gold.withValues(alpha: .35),
                    ),
                  ),
                  child: Text(
                    'Payments coming soon — plan previews and analytics are available, '
                    'but Stripe checkout is disabled during the trial.',
                    style: TextStyle(color: fv.secondaryText, height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                initialValue: selectedId,
                dropdownColor: fv.elevatedSurface,
                decoration: InputDecoration(
                  labelText: 'Business',
                  labelStyle: TextStyle(color: fv.tertiaryText),
                  filled: true,
                  fillColor: fv.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: [
                  for (final business in businesses)
                    DropdownMenuItem(
                      value: business.id,
                      child: Text(
                        business.name,
                        style: TextStyle(color: fv.primaryText),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedBusinessId = value);
                },
              ),
              if (subscription != null && subscription.isActive) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: fv.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FirstVueColors.teal.withValues(alpha: .35),
                    ),
                  ),
                  child: Text(
                    'Active plan: ${subscription.plan.name.toUpperCase()} '
                    '(${subscription.status})',
                    style: TextStyle(color: fv.secondaryText),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _PlanCard(
                name: 'BASIC',
                price: 'FREE',
                features: 'Business listing • Services • Photos • Reviews',
                isCurrent:
                    subscription == null || subscription.plan == BusinessPlan.basic,
                isLoading: false,
                actionLabel: null,
                onAction: null,
                onTap: () => _showMessage(
                  'Basic is your free listing plan — always available.',
                ),
              ),
              _PlanCard(
                name: 'VERIFIED',
                price: verifiedPrice,
                features: 'Verified badge • Trust tools • Owner identity',
                isCurrent: subscription?.plan == BusinessPlan.verified &&
                    subscription!.isActive,
                isLoading: _checkoutLoading,
                actionLabel: !paymentsEnabled
                    ? 'COMING SOON'
                    : (subscription?.plan == BusinessPlan.verified &&
                            subscription!.isActive
                        ? null
                        : 'UPGRADE WITH STRIPE'),
                onAction: !paymentsEnabled
                    ? () => _showComingSoon('Verified')
                    : (subscription?.plan == BusinessPlan.verified &&
                            subscription!.isActive
                        ? null
                        : () => _subscribe(BusinessPlan.verified)),
                onTap: () {
                  if (!paymentsEnabled) {
                    _showComingSoon('Verified');
                    return;
                  }
                  if (subscription?.plan == BusinessPlan.verified &&
                      subscription!.isActive) {
                    _showMessage('Verified is already your active plan.');
                    return;
                  }
                  _subscribe(BusinessPlan.verified);
                },
              ),
              _PlanCard(
                name: 'FIRSTVUE PRO',
                price: proPrice,
                features: 'Analytics • Lead insights • Campaign tools',
                isCurrent:
                    subscription?.plan == BusinessPlan.pro && subscription!.isActive,
                isLoading: _checkoutLoading,
                actionLabel: !paymentsEnabled
                    ? 'COMING SOON'
                    : (subscription?.plan == BusinessPlan.pro &&
                            subscription!.isActive
                        ? null
                        : 'UPGRADE WITH STRIPE'),
                onAction: !paymentsEnabled
                    ? () => _showComingSoon('FirstVue Pro')
                    : (subscription?.plan == BusinessPlan.pro &&
                            subscription!.isActive
                        ? null
                        : () => _subscribe(BusinessPlan.pro)),
                onTap: () {
                  if (!paymentsEnabled) {
                    _showComingSoon('FirstVue Pro');
                    return;
                  }
                  if (subscription?.plan == BusinessPlan.pro &&
                      subscription!.isActive) {
                    _showMessage('FirstVue Pro is already your active plan.');
                    return;
                  }
                  _subscribe(BusinessPlan.pro);
                },
              ),
              if (FeatureFlags.vueBountiesEnabled) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openCampaignDashboard,
                    icon: const Icon(Icons.campaign_outlined),
                    label: const Text('Open VUE Bounty campaign dashboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FirstVueColors.teal,
                      side: BorderSide(
                        color: FirstVueColors.teal.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => CreateBountyDraftSheet.show(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Draft a creator bounty'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FirstVueColors.gold,
                      side: BorderSide(
                        color: FirstVueColors.gold.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'PROMOTE',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              for (final tier in MonetizationProductCatalog.postBoostTiers())
                _Tool(
                  icon: Icons.rocket_launch_outlined,
                  title: '${tier.displayName} · ${tier.priceLabel}',
                  subtitle:
                      'Boost your posts from ••• → Boost Post (draft only for now)',
                  onTap: () => _showComingSoon(tier.displayName),
                ),
              _Tool(
                icon: Icons.push_pin_outlined,
                title: 'Featured placement',
                subtitle: 'Configurable boost products — payments coming soon',
                onTap: () => _showComingSoon('Featured placement'),
              ),
              _Tool(
                icon: Icons.ads_click,
                title: 'Sponsored search & feed',
                subtitle: 'CPC or CPM • Always clearly labeled',
                onTap: () => _showComingSoon('Sponsored placements'),
              ),
              _Tool(
                icon: Icons.campaign_outlined,
                title: 'Promotional campaigns',
                subtitle: FeatureFlags.vueBountiesEnabled
                    ? 'Open your VUE Bounty campaign dashboard'
                    : 'Budget set per campaign product — not hardcoded here',
                onTap: FeatureFlags.vueBountiesEnabled
                    ? _openCampaignDashboard
                    : () => _showComingSoon('Promotional campaigns'),
              ),
              const SizedBox(height: 22),
              Text(
                'PERFORMANCE',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      value: '—',
                      label: 'Video views',
                      onTap: () => _showMessage(
                        'Analytics populate after paid plans go live.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      value: '—',
                      label: 'Profile taps',
                      onTap: () => _showMessage(
                        'Analytics populate after paid plans go live.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      value: '—',
                      label: 'Leads',
                      onTap: () => _showMessage(
                        'Lead insights unlock with FirstVue Pro.',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                paymentsEnabled
                    ? 'Subscriptions are processed securely by Stripe. Your card is never stored in FirstVue.'
                    : 'Paid subscriptions will be available soon. Your card will never be stored in FirstVue.',
                style: TextStyle(color: fv.tertiaryText, height: 1.45),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GrowthData {
  final List<OwnedBusiness> businesses;
  final Map<String, BusinessSubscription> subscriptions;
  final MonetizationProduct verifiedProduct;
  final MonetizationProduct proProduct;

  const _GrowthData({
    required this.businesses,
    required this.subscriptions,
    required this.verifiedProduct,
    required this.proProduct,
  });
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String features;
  final bool isCurrent;
  final bool isLoading;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.features,
    required this.isCurrent,
    required this.isLoading,
    required this.actionLabel,
    required this.onAction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: fv.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCurrent
                    ? FirstVueColors.teal.withValues(alpha: .45)
                    : FirstVueColors.gold.withValues(alpha: .2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: fv.primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            features,
                            style: TextStyle(
                              color: fv.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        color: FirstVueColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Current plan',
                    style: TextStyle(
                      color: FirstVueColors.teal.withValues(alpha: .9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLoading ? null : onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: FirstVueColors.coral,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            FirstVueColors.coral.withValues(alpha: 0.45),
                      ),
                      child: Text(
                        isLoading ? 'OPENING STRIPE...' : actionLabel!,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(icon, color: FirstVueColors.gold),
      title: Text(title, style: TextStyle(color: fv.primaryText)),
      subtitle: Text(subtitle, style: TextStyle(color: fv.secondaryText)),
      trailing: Icon(Icons.chevron_right, color: fv.mutedIcon),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _Metric({
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    return Material(
      color: fv.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: fv.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: fv.tertiaryText, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
