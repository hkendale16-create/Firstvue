import 'package:flutter/material.dart';

import '../config/feature_flags.dart';
import '../config/monetization_config.dart';
import '../navigation/firstvue_page_route.dart';
import '../services/bounty_service.dart';
import '../services/business_submission_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import 'my_businesses_screen.dart';

/// Businesses can queue a draft bounty. Funding stays off until Stripe is live.
class CreateBountyDraftSheet extends StatefulWidget {
  const CreateBountyDraftSheet({super.key});

  static Future<BountyCampaign?> show(BuildContext context) {
    return showModalBottomSheet<BountyCampaign>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateBountyDraftSheet(),
    );
  }

  @override
  State<CreateBountyDraftSheet> createState() => _CreateBountyDraftSheetState();
}

class _CreateBountyDraftSheetState extends State<CreateBountyDraftSheet> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  int _payoutCents = EarnMarketplace.payoutPresetCents[1];
  int _creatorsWanted = 2;
  String? _businessId;
  List<OwnedBusiness> _businesses = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final businesses = await BusinessSubmissionService.fetchMyBusinesses();
    if (!mounted) return;
    setState(() {
      _businesses = businesses;
      _businessId = businesses.isEmpty ? null : businesses.first.id;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 4) {
      setState(() => _error = 'Give the bounty a short title.');
      return;
    }
    if (_businessId == null) {
      setState(() => _error = 'Create or claim a business first.');
      return;
    }
    if (!FeatureFlags.vueBountiesEnabled) {
      setState(() => _error = 'VUE Bounties are not enabled in this build.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final prefs = await UserPreferencesService.fetch();
      final pool = EarnMarketplace.poolCents(
        perCreatorCents: _payoutCents,
        creatorsWanted: _creatorsWanted,
      );
      final campaign = await BountyService.createDraftCampaign(
        title: title,
        bountyType: BountyType.fixed,
        sponsorType: 'business',
        creatorPoolCents: pool,
        maxCampaignBudgetCents: pool,
        maxCreatorPayoutCents: _payoutCents,
        creatorsWanted: _creatorsWanted,
        fixedPayoutCents: _payoutCents,
        performancePayoutCents: 0,
        businessId: _businessId,
        summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
        city: prefs.locationCity,
        state: prefs.locationState,
        locationLabel: prefs.locationLabel,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, campaign);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Draft saved. Funding stays off until payments are approved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fv = context.fv;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, inset + 24),
      child: _loading
          ? const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: FirstVueColors.gold),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Draft a bounty',
                    style: TextStyle(
                      color: fv.primaryText,
                      fontFamily: 'CormorantGaramond',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pay creators to cover your night on VUE. This saves a draft only — '
                    '${EarnMarketplace.splitLabel()}.',
                    style: TextStyle(color: fv.secondaryText, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (_businesses.isEmpty) ...[
                    Text(
                      'You need a business profile before hiring creators.',
                      style: TextStyle(color: fv.secondaryText),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          FirstVuePageRoute(
                            builder: (_) => const MyBusinessesScreen(),
                          ),
                        );
                      },
                      child: const Text('Create or claim a business'),
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _businessId,
                      dropdownColor: fv.elevatedSurface,
                      decoration: const InputDecoration(labelText: 'Business'),
                      items: [
                        for (final b in _businesses)
                          DropdownMenuItem(value: b.id, child: Text(b.name)),
                      ],
                      onChanged: (value) => setState(() => _businessId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      style: TextStyle(color: fv.primaryText),
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Cover Friday night at the patio',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _summary,
                      maxLines: 3,
                      style: TextStyle(color: fv.primaryText),
                      decoration: const InputDecoration(
                        labelText: 'What should they capture?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Payout per creator',
                      style: TextStyle(color: fv.secondaryText, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final cents in EarnMarketplace.payoutPresetCents)
                          ChoiceChip(
                            label: Text(MoneyCents.formatUsd(cents)),
                            selected: _payoutCents == cents,
                            onSelected: (_) =>
                                setState(() => _payoutCents = cents),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Creators wanted: $_creatorsWanted · pool '
                      '${MoneyCents.formatUsd(EarnMarketplace.poolCents(perCreatorCents: _payoutCents, creatorsWanted: _creatorsWanted))}',
                      style: TextStyle(color: fv.secondaryText, fontSize: 13),
                    ),
                    Slider(
                      value: _creatorsWanted.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '$_creatorsWanted',
                      onChanged: (value) =>
                          setState(() => _creatorsWanted = value.round()),
                    ),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: FirstVueColors.coral)),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: FirstVueColors.gold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: Text(_saving ? 'Saving…' : 'Save draft'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
