import 'package:flutter/material.dart';

import '../navigation/firstvue_page_route.dart';
import '../services/bounty_service.dart';
import '../services/creator_earnings_service.dart';
import '../services/location_service.dart';
import '../services/monetization_flags_service.dart';
import '../services/user_preferences_service.dart';
import '../theme/firstvue_theme.dart';
import '../widgets/bounty_nearby_teaser.dart';
import 'create_bounty_draft_sheet.dart';
import 'creator_earnings_screen.dart';

class BountyDiscoveryScreen extends StatefulWidget {
  const BountyDiscoveryScreen({super.key});

  @override
  State<BountyDiscoveryScreen> createState() => _BountyDiscoveryScreenState();
}

class _BountyDiscoveryScreenState extends State<BountyDiscoveryScreen> {
  late Future<_DiscoveryData> _future = _load();

  Future<_DiscoveryData> _load() async {
    final enabled = await MonetizationFlagsService.vueBounties;
    if (!enabled) {
      return const _DiscoveryData(enabled: false, campaigns: []);
    }
    double? lat;
    double? lng;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}
    final campaigns = await BountyService.listNearby(
      latitude: lat,
      longitude: lng,
      limit: 30,
    );
    return _DiscoveryData(enabled: true, campaigns: campaigns);
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
        title: const Text('VUE Bounties'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Creator earnings',
            onPressed: () {
              Navigator.of(context).push(
                FirstVuePageRoute(builder: (_) => const CreatorEarningsScreen()),
              );
            },
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_DiscoveryData>(
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'VUE Bounties are not available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.secondaryText),
                ),
              ),
            );
          }
          if (data.campaigns.isEmpty) {
            return RefreshIndicator(
              color: FirstVueColors.gold,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'No nearby bounties yet',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'CormorantGaramond',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When venues hire coverage, those campaigns show here. Join as a creator now so you can apply the moment one is nearby.',
                    style: TextStyle(color: palette.secondaryText, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final prefs = await UserPreferencesService.fetch();
                        await CreatorEarningsService.optInAsCreator(
                          homeCity: prefs.locationCity,
                          homeState: prefs.locationState,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You’re a creator. We’ll show nearby bounties here.'),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: FirstVueColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Become a creator'),
                  ),
                  TextButton(
                    onPressed: () => CreateBountyDraftSheet.show(context),
                    child: const Text('Venue? Draft a bounty'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: FirstVueColors.gold,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: data.campaigns.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'What’s happening around you that you can participate in — and potentially earn from.',
                    style: TextStyle(color: palette.secondaryText, height: 1.4),
                  );
                }
                final campaign = data.campaigns[index - 1];
                return BountyNearbyTeaser(campaign: campaign);
              },
            ),
          );
        },
      ),
    );
  }
}

class _DiscoveryData {
  final bool enabled;
  final List<BountyCampaign> campaigns;

  const _DiscoveryData({required this.enabled, required this.campaigns});
}
