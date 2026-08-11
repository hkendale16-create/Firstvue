import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/business_submission_service.dart';
import '../services/business_subscription_service.dart';
import '../services/stripe_billing_service.dart';
import '../theme/firstvue_theme.dart';

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
    return _GrowthData(
      businesses: businesses,
      subscriptions: subscriptions,
    );
  }

  Future<void> _refresh() async {
    setState(() => _data = _load());
    await _data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FirstVueColors.background,
      appBar: AppBar(
        title: const Text('FIRSTVUE FOR BUSINESS'),
        backgroundColor: FirstVueColors.background,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
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
              child: Text(
                'Unable to load business growth tools.',
                style: TextStyle(color: Colors.white.withValues(alpha: .7)),
              ),
            );
          }

          final data = snapshot.data!;
          final businesses = data.businesses;

          if (businesses.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                Text(
                  'Turn attention into customers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Create or claim a business profile to activate subscriptions and growth tools.',
                  style: TextStyle(color: Colors.white54, height: 1.45),
                ),
              ],
            );
          }

          _selectedBusinessId ??= businesses.first.id;
          final selected = businesses.firstWhere(
            (business) => business.id == _selectedBusinessId,
          );
          final subscription = data.subscriptions[_selectedBusinessId!];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Turn attention into customers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Managing growth for ${selected.name}',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedBusinessId,
                dropdownColor: FirstVueColors.elevatedSurface,
                decoration: InputDecoration(
                  labelText: 'Business',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: FirstVueColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: [
                  for (final business in businesses)
                    DropdownMenuItem(
                      value: business.id,
                      child: Text(business.name),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedBusinessId = value),
              ),
              if (subscription != null && subscription.isActive) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FirstVueColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: FirstVueColors.teal.withValues(alpha: .35),
                    ),
                  ),
                  child: Text(
                    'Active plan: ${subscription.plan.name.toUpperCase()} '
                    '(${subscription.status})',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _PlanCard(
                name: 'BASIC',
                price: 'FREE',
                features: 'Business listing • Services • Photos • Reviews',
                isCurrent: subscription == null || subscription.plan == BusinessPlan.basic,
                isLoading: false,
                onUpgrade: null,
              ),
              _PlanCard(
                name: 'VERIFIED',
                price: '\$9.99 / month',
                features: 'Verified badge • Trust tools • Owner identity',
                isCurrent: subscription?.plan == BusinessPlan.verified &&
                    subscription!.isActive,
                isLoading: _checkoutLoading,
                onUpgrade: subscription?.plan == BusinessPlan.verified &&
                        subscription!.isActive
                    ? null
                    : () => _subscribe(BusinessPlan.verified),
              ),
              _PlanCard(
                name: 'FIRSTVUE PRO',
                price: '\$29.99 / month',
                features: 'Analytics • Lead insights • Campaign tools',
                isCurrent:
                    subscription?.plan == BusinessPlan.pro && subscription!.isActive,
                isLoading: _checkoutLoading,
                onUpgrade: subscription?.plan == BusinessPlan.pro &&
                        subscription!.isActive
                    ? null
                    : () => _subscribe(BusinessPlan.pro),
              ),
              const SizedBox(height: 22),
              const Text(
                'PROMOTE',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const _Tool(
                icon: Icons.push_pin_outlined,
                title: 'Featured placement',
                subtitle: '\$50–\$300 per campaign — Stripe campaigns coming soon',
              ),
              const _Tool(
                icon: Icons.ads_click,
                title: 'Sponsored search & feed',
                subtitle: 'CPC or CPM • Always clearly labeled',
              ),
              const _Tool(
                icon: Icons.campaign_outlined,
                title: 'Promotional campaigns',
                subtitle: '\$100–\$1,000+ based on budget',
              ),
              const SizedBox(height: 22),
              const Text(
                'PERFORMANCE',
                style: TextStyle(
                  color: FirstVueColors.gold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(child: _Metric(value: '—', label: 'Video views')),
                  SizedBox(width: 10),
                  Expanded(child: _Metric(value: '—', label: 'Profile taps')),
                  SizedBox(width: 10),
                  Expanded(child: _Metric(value: '—', label: 'Leads')),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Subscriptions are processed securely by Stripe. Your card is never stored in FirstVue.',
                style: TextStyle(color: Colors.white54, height: 1.45),
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

  const _GrowthData({
    required this.businesses,
    required this.subscriptions,
  });
}

class _PlanCard extends StatelessWidget {
  final String name;
  final String price;
  final String features;
  final bool isCurrent;
  final bool isLoading;
  final VoidCallback? onUpgrade;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.features,
    required this.isCurrent,
    required this.isLoading,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: FirstVueColors.surface,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      features,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
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
          ] else if (onUpgrade != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading ? null : onUpgrade,
                style: FilledButton.styleFrom(
                  backgroundColor: FirstVueColors.coral,
                  foregroundColor: Colors.white,
                ),
                child: Text(isLoading ? 'OPENING STRIPE...' : 'UPGRADE WITH STRIPE'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Tool({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    leading: Icon(icon, color: FirstVueColors.gold),
    title: Text(title, style: const TextStyle(color: Colors.white)),
    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
  );
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
    decoration: BoxDecoration(
      color: FirstVueColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    ),
  );
}
