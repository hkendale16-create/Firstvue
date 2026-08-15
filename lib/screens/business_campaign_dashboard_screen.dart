import 'package:flutter/material.dart';

import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/bounty_service.dart';
import '../services/monetization_flags_service.dart';
import '../theme/firstvue_theme.dart';
import 'bounty_detail_screen.dart';

class BusinessCampaignDashboardScreen extends StatefulWidget {
  const BusinessCampaignDashboardScreen({super.key});

  @override
  State<BusinessCampaignDashboardScreen> createState() =>
      _BusinessCampaignDashboardScreenState();
}

class _BusinessCampaignDashboardScreenState
    extends State<BusinessCampaignDashboardScreen> {
  late Future<_DashData> _future = _load();

  Future<_DashData> _load() async {
    final enabled = await MonetizationFlagsService.vueBounties;
    if (!enabled) {
      return const _DashData(enabled: false, rows: []);
    }
    final campaigns = await BountyService.fetchMyCampaigns();
    final rows = <_CampaignRow>[];
    for (final c in campaigns) {
      final metrics = await BountyService.fetchMetrics(c.id);
      rows.add(_CampaignRow(campaign: c, metrics: metrics));
    }
    final funding = await BountyService.canShowFundingActions();
    return _DashData(enabled: true, rows: rows, fundingEnabled: funding);
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
        title: const Text('Campaign dashboard'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            );
          }
          final data = snapshot.data;
          if (data == null || !data.enabled) {
            return Center(
              child: Text(
                'Campaign tools are not enabled.',
                style: TextStyle(color: palette.secondaryText),
              ),
            );
          }
          if (data.rows.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'No campaigns yet',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'CormorantGaramond',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create draft VUE Bounty campaigns from your business tools. Metrics only show data FirstVue actually tracks — never manufactured ROI.',
                  style: TextStyle(color: palette.secondaryText, height: 1.45),
                ),
                if (!data.fundingEnabled) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Real funding is disabled until a payment provider is approved.',
                    style: TextStyle(color: palette.tertiaryText, fontSize: 12),
                  ),
                ],
              ],
            );
          }

          return RefreshIndicator(
            color: FirstVueColors.gold,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: data.rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final row = data.rows[index];
                final c = row.campaign;
                final m = row.metrics;
                return Material(
                  color: palette.elevatedSurface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(context).push(
                        FirstVuePageRoute(
                          builder: (_) =>
                              BountyDetailScreen(campaignId: c.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.status.name} · budget ${MoneyCents.formatUsd(c.maxCampaignBudgetCents)}',
                            style: TextStyle(color: palette.secondaryText),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              _MetricChip('Apps', '${m.applicationsCount}'),
                              _MetricChip('Accepted', '${m.acceptedCreatorsCount}'),
                              _MetricChip('VUEs', '${m.completedVuesCount}'),
                              _MetricChip('Views', '${m.vueViewsCount}'),
                              _MetricChip('Saves', '${m.savesCount}'),
                              _MetricChip('Shares', '${m.sharesCount}'),
                              _MetricChip('Visits', '${m.eventProfileVisits}'),
                              _MetricChip('Directions', '${m.directionTaps}'),
                              _MetricChip('Tickets', '${m.ticketConversions}'),
                              _MetricChip(
                                'Payouts',
                                MoneyCents.formatUsd(m.creatorPayoutsCents),
                              ),
                              _MetricChip(
                                'Fees',
                                MoneyCents.formatUsd(m.platformFeesCents),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(color: palette.secondaryText, fontSize: 12),
      ),
    );
  }
}

class _CampaignRow {
  final BountyCampaign campaign;
  final BountyCampaignMetrics metrics;
  const _CampaignRow({required this.campaign, required this.metrics});
}

class _DashData {
  final bool enabled;
  final List<_CampaignRow> rows;
  final bool fundingEnabled;

  const _DashData({
    required this.enabled,
    required this.rows,
    this.fundingEnabled = false,
  });
}
