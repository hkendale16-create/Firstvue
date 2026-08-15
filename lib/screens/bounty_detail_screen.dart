import 'package:flutter/material.dart';

import '../config/monetization_config.dart';
import '../services/bounty_service.dart';
import '../services/monetization_flags_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/sponsored_disclosure_badge.dart';

class BountyDetailScreen extends StatefulWidget {
  final String campaignId;

  const BountyDetailScreen({super.key, required this.campaignId});

  @override
  State<BountyDetailScreen> createState() => _BountyDetailScreenState();
}

class _BountyDetailScreenState extends State<BountyDetailScreen> {
  late Future<_DetailData> _future = _load();
  bool _applying = false;

  Future<_DetailData> _load() async {
    final campaign = await BountyService.fetchCampaign(widget.campaignId);
    if (campaign == null) {
      return const _DetailData(campaign: null, requirements: null);
    }
    final requirements = await BountyService.fetchRequirements(
      campaignId: campaign.id,
      version: campaign.currentRequirementsVersion,
    );
    return _DetailData(campaign: campaign, requirements: requirements);
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await BountyService.apply(campaignId: widget.campaignId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted.')),
      );
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Bounty details'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: FirstVueColors.gold),
            );
          }
          final campaign = snapshot.data?.campaign;
          if (campaign == null) {
            return Center(
              child: Text(
                'Bounty not found.',
                style: TextStyle(color: palette.secondaryText),
              ),
            );
          }
          final req = snapshot.data?.requirements;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              SponsoredDisclosureBadge(label: campaign.disclosureLabel),
              const SizedBox(height: 14),
              Text(
                campaign.title,
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'CormorantGaramond',
                ),
              ),
              if (campaign.locationLabel != null || campaign.city != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (campaign.locationLabel != null) campaign.locationLabel,
                    if (campaign.city != null)
                      [campaign.city, campaign.state].whereType<String>().join(', '),
                  ].whereType<String>().join(' · '),
                  style: TextStyle(color: palette.secondaryText),
                ),
              ],
              const SizedBox(height: 18),
              _MoneyBlock(
                label: 'Creator pool',
                value: campaign.poolLabel,
              ),
              const SizedBox(height: 8),
              _MoneyBlock(
                label: 'Compensation',
                value: campaign.compensationSummary,
              ),
              const SizedBox(height: 8),
              _MoneyBlock(
                label: 'Creators',
                value:
                    '${campaign.creatorsAccepted}/${campaign.creatorsWanted} accepted · ${campaign.slotsRemaining} spots left',
              ),
              const SizedBox(height: 20),
              Text(
                'Requirements',
                style: TextStyle(
                  color: palette.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (req == null)
                Text(
                  campaign.description ?? 'Requirements will be listed before you apply.',
                  style: TextStyle(color: palette.secondaryText, height: 1.45),
                )
              else ...[
                if (req.isLocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Requirements locked (v${req.version}) after creator acceptance.',
                      style: TextStyle(
                        color: FirstVueColors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                _ReqLine(
                  'Deliverables',
                  req.deliverables ?? campaign.description ?? '—',
                ),
                if (req.vueMinSeconds != null || req.vueMaxSeconds != null)
                  _ReqLine(
                    'VUE length',
                    [
                      if (req.vueMinSeconds != null) 'min ${req.vueMinSeconds}s',
                      if (req.vueMaxSeconds != null) 'max ${req.vueMaxSeconds}s',
                    ].join(' · '),
                  ),
                if (req.contentCategory != null)
                  _ReqLine('Category', req.contentCategory!),
                if (req.requiredTag != null)
                  _ReqLine('Required tag', req.requiredTag!),
                if (req.submissionDeadlineAt != null)
                  _ReqLine(
                    'Deadline',
                    req.submissionDeadlineAt!.toLocal().toString().split('.').first,
                  ),
                _ReqLine(
                  'Max payout',
                  MoneyCents.formatUsd(
                    req.maxPayoutCents ?? campaign.maxCreatorPayoutCents,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Businesses purchase agreed content/participation — not guaranteed positive opinions, star ratings, or misleading testimonials.',
                style: TextStyle(
                  color: palette.tertiaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (campaign.status == BountyCampaignStatus.active)
                FilledButton(
                  onPressed: _applying ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: FirstVueColors.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_applying ? 'Applying…' : 'Apply'),
                )
              else
                Text(
                  'This bounty is ${campaign.status.name} and not open for applications.',
                  style: TextStyle(color: palette.secondaryText),
                ),
              const SizedBox(height: 12),
              FutureBuilder<bool>(
                future: MonetizationFlagsService.bountyFunding,
                builder: (context, snap) {
                  final fundingOn = snap.data ?? false;
                  if (fundingOn) {
                    return Text(
                      'Funding tools are reserved for authorized server flows.',
                      style: TextStyle(color: palette.tertiaryText, fontSize: 12),
                    );
                  }
                  return Text(
                    'Real campaign funding is disabled in Early Access.',
                    style: TextStyle(color: palette.tertiaryText, fontSize: 12),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoneyBlock extends StatelessWidget {
  final String label;
  final String value;

  const _MoneyBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.tertiaryText, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReqLine extends StatelessWidget {
  final String label;
  final String value;

  const _ReqLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final palette = FirstVueColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: palette.secondaryText, height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _DetailData {
  final BountyCampaign? campaign;
  final BountyRequirements? requirements;

  const _DetailData({required this.campaign, required this.requirements});
}
