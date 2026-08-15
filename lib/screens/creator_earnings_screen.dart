import 'package:flutter/material.dart';

import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/bounty_service.dart';
import '../services/creator_earnings_service.dart';
import '../theme/firstvue_theme.dart';
import 'bounty_detail_screen.dart';

class CreatorEarningsScreen extends StatefulWidget {
  const CreatorEarningsScreen({super.key});

  @override
  State<CreatorEarningsScreen> createState() => _CreatorEarningsScreenState();
}

class _CreatorEarningsScreenState extends State<CreatorEarningsScreen> {
  late Future<_EarningsData> _future = _load();

  Future<_EarningsData> _load() async {
    CreatorProfile? profile;
    try {
      profile = await CreatorEarningsService.ensureCreatorProfile();
    } catch (_) {}
    final summary = await CreatorEarningsService.fetchEarningsSummary();
    final reputation = profile == null
        ? null
        : await CreatorEarningsService.fetchReputation(profile.profileId);
    final applications = await BountyService.fetchMyApplications();
    final campaigns = await BountyService.listNearby(limit: 10);
    final history = await CreatorEarningsService.fetchLedgerHistory(limit: 30);
    final payoutsOn = await CreatorEarningsService.canShowPayoutActions();
    return _EarningsData(
      summary: summary,
      reputation: reputation,
      applications: applications,
      activeNearby: campaigns,
      history: history,
      payoutsEnabled: payoutsOn,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Creator Earnings'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_EarningsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            );
          }
          final data = snapshot.data ??
              const _EarningsData(
                summary: CreatorEarningsSummary.empty,
                reputation: null,
                applications: [],
                activeNearby: [],
                history: [],
                payoutsEnabled: false,
              );

          return RefreshIndicator(
            color: FirstVueColors.gold,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                if (data.reputation != null) ...[
                  Text(
                    '${data.reputation!.level.emoji} ${data.reputation!.level.label}',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data.reputation!.completedCampaigns} completed · '
                    '${(data.reputation!.completionBps / 100).toStringAsFixed(0)}% completion · '
                    '${data.reputation!.verifiedConversions} verified conversions',
                    style: TextStyle(color: palette.secondaryText, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _BalanceTile(
                        label: 'Available',
                        value: data.summary.availableLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BalanceTile(
                        label: 'Pending',
                        value: data.summary.pendingLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _BalanceTile(
                  label: 'Lifetime Earnings',
                  value: data.summary.lifetimeLabel,
                  wide: true,
                ),
                const SizedBox(height: 10),
                Text(
                  'Balances are ledger-derived read models — not a stored-value wallet. Clients cannot change earnings.',
                  style: TextStyle(color: palette.tertiaryText, fontSize: 11, height: 1.35),
                ),
                const SizedBox(height: 22),
                _SectionTitle('Active Bounties'),
                if (data.activeNearby.isEmpty)
                  _Empty('No active nearby bounties.')
                else
                  ...data.activeNearby.take(5).map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.title, style: TextStyle(color: palette.primaryText)),
                      subtitle: Text(
                        '${c.poolLabel} · ${c.slotsRemaining} spots',
                        style: TextStyle(color: palette.secondaryText),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          FirstVuePageRoute(
                            builder: (_) =>
                                BountyDetailScreen(campaignId: c.id),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                _SectionTitle('Applications'),
                if (data.applications.isEmpty)
                  _Empty('No applications yet.')
                else
                  ...data.applications.map(
                    (a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        a.status.name,
                        style: TextStyle(color: palette.primaryText),
                      ),
                      subtitle: Text(
                        'Campaign ${a.campaignId.substring(0, 8)}… · req v${a.requirementsVersion}',
                        style: TextStyle(color: palette.secondaryText),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                _SectionTitle('Pending Earnings'),
                _Empty(
                  data.summary.pendingCents == 0
                      ? 'Nothing pending.'
                      : '${data.summary.pendingLabel} awaiting eligibility window.',
                ),
                const SizedBox(height: 12),
                _SectionTitle('Earnings History'),
                if (data.history.isEmpty)
                  _Empty('No ledger entries yet.')
                else
                  ...data.history.map((row) {
                    final cents = (row['amount_cents'] as num?)?.toInt() ?? 0;
                    final type = row['entry_type'] as String? ?? 'entry';
                    final direction = row['direction'] as String? ?? 'credit';
                    final signed = direction == 'debit' ? -cents : cents;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(type, style: TextStyle(color: palette.primaryText)),
                      trailing: Text(
                        MoneyCents.formatUsd(signed),
                        style: TextStyle(
                          color: signed < 0 ? palette.error : FirstVueColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                _SectionTitle('Payout Settings'),
                if (!data.payoutsEnabled)
                  _Empty(
                    'Cash payouts are disabled until a compliant marketplace payout provider is approved.',
                  )
                else
                  Text(
                    'Payout provider integration pending — UI only.',
                    style: TextStyle(color: palette.secondaryText),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final String label;
  final String value;
  final bool wide;

  const _BalanceTile({
    required this.label,
    required this.value,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.tertiaryText, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'CormorantGaramond',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: FirstVueColors.of(context).primaryText,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: FirstVueColors.of(context).secondaryText,
          height: 1.35,
        ),
      ),
    );
  }
}

class _EarningsData {
  final CreatorEarningsSummary summary;
  final CreatorReputation? reputation;
  final List<BountyApplication> applications;
  final List<BountyCampaign> activeNearby;
  final List<Map<String, dynamic>> history;
  final bool payoutsEnabled;

  const _EarningsData({
    required this.summary,
    required this.reputation,
    required this.applications,
    required this.activeNearby,
    required this.history,
    required this.payoutsEnabled,
  });
}
